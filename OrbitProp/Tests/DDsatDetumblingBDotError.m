% DDsatDetumblingBdotError is a test script for OrbitProp
%
%This file is to simulate DDsat detumbling by using Bdot method. Bdot is
%calculated from product of change angular rate and local magnetic field
%This simulation includes all error/bias/uncertainties source from complete
%control system

%--- Copyright notice ---%
% Copyright 2012-2013 Cranfield University
% Written by Josep Virgili and Daniel Zhou Hao
%
% This file is part of the AstroLab
%
% AstroLab is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% AstroLab is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with AstroLab.  If not, see <http://www.gnu.org/licenses/>.

%--- CODE ---%
%% Clean Code
% Comment off clear all and clc when doing statistic 
% clear all;
% close all;
% clc;

%Add paths
addpath('..')
addpath('IGRF')
OrbitToPath

Re = 6378136.49; %Equatorial Earth radius m [source: SMAD 3rd edition]
mu=398600.441e9;  %GM Earth m3/s2 [source: SMAD 3rd edition]
we = 7.292115e-5; %Earth Angular velocity in rad/s [source: SMAD 3rd edition]

%Initial conditions
h = 320*1e3; %Initial altitude in m
i = 79; %Inclination
v0 = sqrt(mu/(Re+h)); %Initial velocity
x0 = [Re+h,0,0,0,v0*cosd(i),v0*sind(i)]; %Initial vector state
%Atmosphere co-rotation velocity
Vco = norm(cross([0;0;we],x0(1:3))); 

tf = 0:1:50 * 60; %Integration time
rx=deg2rad(rand()*360);
ry=deg2rad(rand()*360);
rz=deg2rad(rand()*360);
q0=angle2quat(rx,ry,rz,'XYZ'); %Initial attitude quaterion

%Initial angular rate (make it random!)
w1=20*(rand()-0.5);
w2=20*(rand()-0.5);
w3=20*(rand()-0.5);
w0=deg2rad([w1,w2,w3]); %Format initial angular rate

%Format the initial 
x0=[x0,q0,w0];

% Spacecarft propetries
% data.sc_prop.I=[0.0042,0,0;
%                 0,0.0104,0;
%                 0,0,0.0104]; %Inertia
 
%Spacecarft propetries
data.sc_prop.I=[0.04,0,0;
                0,0.0177,0;
                0,0,0.0177]; %Inertia

 %Models
data.models={@GravJ4};
data.models(end+1)={@MagBdotError};

%Configure MagBdot
data.MagBdotError.C = 9e5;  % Control Coefficient
data.MagBdotError.A = [0.2,0.2,0.2];
data.MagBdotError.Y = 2012; %Not using
data.MagBdotError.w = [0,deg2rad(-360/90/60),0]; % Not using
data.MagBdotError.verb=1;

data.MagBdotError.GE = deg2rad ([0.1,0.1,0.1]');   % [0.1,0.1,0.1]'
data.MagBdotError.MMR =  ones(3,1)*3.5e-6;               % 7 mili gauss = 0.7 microteslas
% #1. With 3.5e-6 Teslas
% #2. With 0.7e-6 Teslas
% #3. With 0.7e-8 Teslas


data.MagBdotError.MTR = ones(3,1)*0.2/(2^8);   % +- 8 bits of 2 Am2
data.MagBdotError.MTB = ones(3,1)*normrnd (0, 0.05*0.2); 
% #1. With 5 Percent Actuational Level Bias, ()
% #2. With 10 Percent Acuational Level Bias, ()
% #3. With 15 Percent Acuational Level Bias, ()

[t,x] = OrbitProp(x0,tf(1),tf(2:end),data);

%%
%--- Rate plot ---%
% Comment off Plot when doing statistic 
% figure
% plot(t/60,rad2deg(x(:,11)),t/60,rad2deg(x(:,12)),t/60,rad2deg(x(:,13)));
% xlabel('Time [min]')
% ylabel('Angular rates [deg/s]')
% legend('Roll','Pitch','Yaw')
% title('Angular rates')           
%%

%Calculate Torque
Torque=[];

for i=1:length(t)
 [A,Torque(end+1,1:3),E] = MagBdotError(t(i),x(i,:)',data);
end

%%
%--- Torque Plot ---%
% Comment off Plot when doing statistic 
% 
% figure
% plot(t/60,Torque(:,1),t/60,Torque(:,2),t/60,Torque(:,3))
% xlabel('Time [mins]');
% ylabel('Torque [Nm]');
% legend('x Torquer','y Torquer','z Torquer');
% title('Torque Plot');
%%

%--- Power & Energy Plots ---%
Al = []; %Actuation level
PT = []; %Total Power
PP = []; %Partial Power
 m_v=[];
 p_v=[];
% Power per actuation level Am2 of actuators (parameter that needs
% adjusting to every case)
px = 0.57/0.2;
py = 0.2/0.2;
pz = 0.2/0.2;
p = [px,py,pz];


for i=1:length(t)
 %--- Get magnetic field ---%
    %Latitude and longitude
    we = 7.292115e-5; %Earth Angular velocity in rad/s [source: SMAD 3rd edition]
    Req=6378136.49;   %Equatorial Earth radius m [source: SMAD 3rd edition]
    f=1/298.256;      %Flattening factor [source: SMAD 3rd edition]
    lla=ecef2lla(x(i,1:3),f,Req); %Compute taking assuming Earth as an ellipsoid
    lat=lla(1);
    lon=lla(2);
    h=lla(3);
    %Take into account rotation of the earth
    lon = mod(lon - t(i)*we*180/pi,365);
    if lon>180
        lon = lon-360;
    elseif lon<-180
        lon = lon+360;
    end
    
    %Magnetic field in T
    mfield_ECEF = igrf11magm(h, lat, lon, data.MagBdotError.Y)/1e9;
    %Change magnetic field to body axes.
    DCM = quat2dcm([x(i,10),x(i,7:9)]);
    mfield = DCM*mfield_ECEF';
    mfield_round = round(mfield./data.MagBdotError.MMR).*data.MagBdotError.MMR;
% Compute the rounded mfield
    
    
% Define actuation value
% Dont have to define [] in advance since I am not using 'end' keyword.

% Actuation Level

Bdot = cross(mfield,(x(11:13)));
m = -1*(data.MagBdotError.C) * Bdot;

% Check if actuation level saturated
    if abs(m(1))>data.MagBdotError.A(1)
        %Adjust to maximum
        m(1)=sign(m(1))*data.MagBdotError.A(1);
    end
    if abs(m(2))>data.MagBdotError.A(2)
        %Adjust to maximum
        m(2)=sign(m(2))*data.MagBdotError.A(2);
    end
    if abs(m(3))>data.MagBdotError.A(3)
        %Adjust to maximum
        m(3)=sign(m(3))*data.MagBdotError.A(3);
    end
   
m = round(m(:)./data.MagBdotError.MTR(:)).*data.MagBdotError.MTR(:)+data.MagBdotError.MTB(:);
% Compute the rounded actuation level

m_v(end+1,1:3) = m;


% Total Power 
PT(end+1) = sum(abs(m_v(end,:)).*p);
% Individual Power
PP(end+1,1:3)= abs(m_v(end,1:3)).*p;
% Actual Level
Al(end+1,1:3) = m_v(end,1:3);
end



% Comment the following plot when using statistics 
% -- Power plot -- %
% figure
% plot(t/60,PT,t/60,PP(:,1),t/60,PP(:,2),t/60,PP(:,3))
% xlabel('Time [mins]');
% ylabel('Total Power [W]');
% legend('Total Power','x power','y power','z power');
% title('Power Plot');
% 

% -- Actuation level plot --%
% figure
% plot(t/60,Al(:,1),t/60,Al(:,2),t/60,Al(:,3))
% xlabel('Time [mins]');
% ylabel('Actuation Level [Am2]');
% legend('x actuation level','y actuation','z actuation');
% title('Actuation Level Plot');
