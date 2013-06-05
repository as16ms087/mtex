function [rgb,options] = h2HSV(h,cs,varargin)
% converts orientations to rgb values

%% colorize fundamental region

options = extract_option(varargin,'antipodal');
varargin = delete_option(varargin,'complete');

[minTheta,maxTheta,minRho,maxRho] = getFundamentalRegionPF(cs,varargin{:}); %#ok<ASGLU>
maxRho = maxRho - minRho;
h = vector3d(h(:)); h = h./norm(h);
switch Laue(cs)
  
  case {'-1','-3','4/m','6/m'}
    if check_option(varargin,'antipodal')
      h(getz(h)<0) = -h(getz(h)<0);
    end
    [theta,rho] = polar(h(:));
    rho = mod(rho,maxRho)./maxRho;
    if max(theta(:)) < pi / 3
      theta = theta./max(theta(:))*pi/2;
    end
    pm = theta(:) >= pi/2;
    if any(pm), c(pm,:) = hsv2rgb([rho(pm),ones(sum(pm),1),2-theta(pm)./pi*2]); end
    if any(~pm), c(~pm,:) = hsv2rgb([rho(~pm),theta(~pm)./pi*2,ones(sum(~pm),1)]); end
    rgb = reshape(c,[size(h),3]);
    return
  case '2/m'
    if check_option(varargin,'antipodal')
      h(gety(h)<0) = -h(gety(h)<0);
    end
    
    rho = atan2(getx(h),getz(h));
    theta = acos(gety(h));
    
    rho = mod(rho,maxRho)./maxRho;
    if max(theta(:)) < pi / 3
      theta = theta./max(theta(:))*pi/2;
    end
    pm = theta(:) >= pi/2;
    if any(pm), c(pm,:) = hsv2rgb([rho(pm),ones(sum(pm),1),2-theta(pm)./pi*2]); end
    if any(~pm), c(~pm,:) = hsv2rgb([rho(~pm),theta(~pm)./pi*2,ones(sum(~pm),1)]); end
    rgb = reshape(c,[size(h),3]);
    return
  case 'm-3m'
    constraints = [vector3d(1,-1,0),vector3d(-1,0,1),yvector,zvector];
    constraints = constraints ./ norm(constraints);
    center = sph2vec(pi/6,pi/8); 
  case 'm-3'
    if ~check_option(varargin,'antipodal')
      warning('For symmetry ''m-3'' only antipodal colorcoding is supported right now'); %#ok<WNTAG>
    end
    
    varargin = delete_option(varargin,'antipodal');
    constraints = [vector3d(1,-1,0),vector3d(-1,0,1),yvector,zvector];
    constraints = constraints ./ norm(constraints);
    center = sph2vec(pi/6,pi/8);
    
  otherwise
    
    if check_option(varargin,'antipodal'), maxRho = maxRho * 2;end
    constraints = [yvector,axis2quat(zvector,maxRho/2) * (-yvector),zvector];
    %constraints = [-axis2quat(zvector,-maxrho/2) * yvector];
    center = sph2vec(pi/4,maxRho/4);
end

[sh,pm,rho_min] = project2FundamentalRegion(vector3d(h),{cs},varargin{:});

%% special case m-3

if strcmp(Laue(cs),'m-3')
  
  [theta,rho] = polar(sh);
  pm = rho > pi/4;
  rho(pm) = pi/2 - rho(pm);
  sh = vector3d('polar',theta,rho);
  
end

% if the Fundamental region does not start at rho = 0
constraints = axis2quat(zvector,rho_min) * constraints;
center = axis2quat(zvector,rho_min) * center;


%% compute angle
rx = center - zvector; rx = rx ./ norm(rx);
ry = cross(center,rx); ry = ry ./ norm(ry);
dv = (center - sh); dv = dv ./ norm(dv);
omega = mod(atan2(dot(rx,dv),dot(ry,dv))-pi/2,2*pi);
omega(isnan(omega)) = 0;
omega = omega(:);


%% compute saturation

% center
center = get_option(varargin,'colorcenter',center);
center = project2FundamentalRegion(center./ norm(center),{cs},varargin{:});
cc = cross(sh,center);
cc = cc ./ norm(cc);

options = [{'colorcenter',center},options];

if check_option(varargin,'radius') % linear interpolation to the radius
  
  radius = get_option(varargin,'radius',1);
  dh(:,:) = 1-min(1,angle(sh,center)./radius);
  options = [options,{'radius',radius}];

elseif quantile(angle(sh,center),0.9) < 10*degree
  
  radius = quantile(angle(sh,center),0.9);
  dh(:,:) = 1-min(1,angle(sh,center)./radius);
  options = [options,{'radius',radius}];
  
else % linear interpolation to the boundaries
  
  dh = zeros([size(sh),length(constraints)]);
  for i = 1:length(constraints)
    
    % boundary points
    bc = cross(cc,constraints(i));
    bc = bc ./ norm(bc);

    % compute distances
    dh(:,:,i) = angle(-sh,bc)./angle(-center,bc);
    dh(isnan(dh)) = 1;
  end
  dh = min(dh,[],3);
end

dh(imag(dh) ~=0 ) = 0;
dh = dh(:);


%% compute colors
% black center
dh(pm) = (1-dh(pm))./2;

% white center
dh(~pm) = 0.5+dh(~pm)./2;

% saturation
grayValue = get_option(varargin,'grayValue',1);

L = (dh - 0.5) .* grayValue(:) + 0.5;

S = grayValue(:) .* (1-abs(2*dh-1)) ./ (1-abs(2*L-1));

%% compute colors

[h,s,v] = hsl2hsv(omega./2./pi,S,L);
rgb = hsv2rgb(h,s,v);

