classdef lyttle_model < handle
    
    % Version 4, modified by YW, 2022-04-01
    % Class-based Lyttle model in Cube Solver refactored from
    % lyttle_in_cube_variational_V2.m for extensibility
    % 
    % Minimal examples to run (with default parameter and initial values):
    %   M = lyttle_model;
    %   M.solve;
    %   M.plot;
    %
    % ===========================
    % Detailed instructions:
    % ===========================
    % A class of lyttle_model enables us to create a model object and
    % change its parameter values interactively.
    %
    % 1, First step of running this solver is always to call its constructor:
    %
    %   M = lyttle_model(xinit,vinit,tmax,Lyapunov);
    %
    % where 
    %       xinit,vinit -- the initial values of x and v 
    %       tmax        -- the endtime of the ode integration
    %       Lyapunov    -- 'off' by default, setting to 'on' the model will calculate the Lyapunov exponent automatically when solving 
    % You can enter any number of inputs to the constructor since all four of them have pre-defined default values.
    %
    % 2, After construct a model, typing M in command window and entering will display
    % all current properties set. In addition to the above four, there are also: 
    %
    %           yinit   -- concatenation of xinit and vinit
    %          domain   -- current domain (0 interior, 1-7 walls)
    %         grasper   -- current grasper status (0 close, 1 open)
    %               t   -- time array
    %            yext   -- full solution array, each new solution will be appended to new row (yext = [yext; ynew])
    %             prc   -- phase response curve
    %              t0   -- current time (scalar)
    %              y0   -- current solution (same size as yinit)  
    %             Lyp   -- array of Lyapunov exponent
    %     scalefactor   -- array of Lyp exp scale factor
    %            Salt   -- array of Saltation matrix (v+ = Sv-)
    %         t_event   -- keeping the times of events (wall hitting) 
    %    domain_event   -- domains where trajectory enters
    %          t_exit   -- keeping the times of leaving walls
    %     domain_exit   -- domains where trajectory leaves
    %       Jump_exit   -- array of Jump matrix at exit (z- = Jz+)
    % 
    % It is not recommended to manually change any of these values because
    % they are all counted as model "outputs"
    % You can check their values any time using the dot reference, such as M.grasper
    %  
    % 3, Type "methods(M)" will show the available methods in the model:  
    % 
    %           solve   -- requires no input, solve the model with given initial values
    %            plot   -- requires no input, plot the solutions (alway solve before plot)
    %      findPeriod   -- requires two guesses L and R, using Bisection method to find an estimated period in [L,R] of the ODE
    %      lyttle_ODE   -- ODE of the model, used internally
    %
    % ===========================
    % Some other usage examples:
    % ===========================
    % ** Plot Lyapunov exponent
    %
    %   M = lyttle_model;
    %   M.tmax = 50; % solve for a longer time
    %   M.Lyapunov = 'on'; % turn on Lyp exp calculation
    %   M.solve;
    %   M.plot; % plot solution
    %   plot(M.t,M.Lyp,'*') % plot Lyp exp
    % 
    % ** Estimate solution period
    % 
    %   >> M = lyttle_model;
    %   >> M.findPeriod(4.5,5) % From the solution, it looks like the period is between 4.5 and 5
    %   ...................
    %   ans =
    %
    %        4.8861
    
    
    properties (Constant,Hidden)
        tau_a=0.05; % time constant for neural activity
        tau_m=2.45; % time constant for muscle activation
        mu=1e-6; % original standard value is 1e-5
        gamma=2.4;
%         eps1=1e-4; % in the MS all epsilon are equal
%         eps2=1e-4; % in the MS all epsilon are equal
%         eps3=1e-4; % in the MS all epsilon are equal
        s1=.5; % this is S0 in the MS
        s2=.5; % this is S1 in the MS
%         s3=.25; % this is S2 in the MS
        sig1=-1; % this is sigma0 in the MS
        sig2=1; % this is sigma1 in the MS
        sig3=1; % this is sigma2 in the MS
        kappa=.5; % This is the factor by which mu is reduced when seaweed is "present in the buccal cavity" i.e. during swallowing.
        umax=1; % peak muscle activation
        br=0.4; % grasper damping constant
        
        reltol = 1e-13; % ode15s tolerance
        abstol = 1e-13; % ode15s tolerance
        maxstep=1e-3;
        Lyapunov = 'off';
        
%         c0=1.0; % Position of shortest length for I2
%         c1=1.1; % Position of shortest length for I3
        w0=2;   % Maximal effective length of I2
        w1=1.1; % Maximal effective length of I3
    end
    
    properties
        eps1
        eps2
        eps3
        xinit
        vinit
        tmax
        
        c0=1.0; % Position of shortest length for I2
        c1=1.1; % Position of shortest length for I3
        
        k0 = 1;  % protractor I2 muscle strength
        k1 = -1; % retractor I3 muscle strength
        
        s3=.25; % this is S2 in the MS
    end
    
    properties
        tinit  % initial time, added 4/22/2022
        yinit
    end
    
    properties
        nu
        nu1_close
        nu1_open
        domain
        grasper
        t = []; % Full time
        tspan = []; % Full unique time (remove duplicate)
        yext = []; % Full solution
        prc=[]; % phase response solution
        prct=[]; % time for prc
        t0 % Initial/current time
        y0 % Initial/current solution
        Lyp = []; % Lyapunov exponent
        scalefactor % Lyp exp scale factor
        
        Salt = {}; % Record saltation matrices
        t_event = []; % Record time when saltation matrix is multiplied
        domain_event = []; % Record the domain when event happened
        
        t_exit = []; % Record times exiting a wall or crossing the open/close bdry
        domain_exit = []; % Record the domain when exit happened
        Jump_exit = {}; % Record inverse jump matrices associated with exit
        
        t_open_to_close = []; % Record times when switching from open to close
        y_open_to_close = [];
        
        t_close_to_open = []; % Record times when switching from close to open
        y_close_to_open = [];
        
        t_exit_a0 = []; % record times exiting wall a0=0
        t_enter_a0 = []; % record times entering wall a0=0
        
        t_exit_a2 = []; % record times exiting wall a2=0
        t_enter_a2 = []; % record times entering wall a2=0
    end
    
    properties(SetAccess = private)
        isPiecewise
    end
    
    methods
        function model = lyttle_model(varargin)
            
            p = inputParser;
            
            addOptional(p, 'eps1', 1e-4, @(x)validateattributes(x,...
                {'numeric'},{'nonempty'}));
            addOptional(p, 'eps2', 1e-4, @(x)validateattributes(x,...
                {'numeric'},{'nonempty'}));
            addOptional(p, 'eps3', 1e-4, @(x)validateattributes(x,...
                {'numeric'},{'nonempty'}));
            addOptional(p, 'xinit', [0.900321164137428;
                0.083551935956201;
                0.000031666995903;
                0.747647099749367;
                0.246345045901938;
                0.649984712236374;
                -8.273162075117845;
                0.01]', @(x)validateattributes(x,...
                {'numeric'},{'nonempty'}));
             addOptional(p, 'tinit', 0, @(x)validateattributes(x,...
                {'numeric'},{'nonempty'}));
            addOptional(p, 'vinit', [0,0,0,0,0,0], @(x)validateattributes(x,...
                {'numeric'},{'nonempty'}));
            addOptional(p, 'tmax', 4.886087799072266, @(x)validateattributes(x,...
                {'numeric'},{'nonempty'}));
            addOptional(p, 'nu', 0);
            
           
            parse(p, varargin{:})
            
            model.nu = p.Results.nu;
            
            % If the input nu is a vector, then the perturbation is piecewise; 
            % if nu is a scalar, then the perturbation is uniform
            if length(model.nu) > 1
                model.isPiecewise = true;
                model.nu1_close = model.nu(1);
                model.nu1_open = model.nu(2);
            else
                model.isPiecewise = false;
                model.nu1_close = model.nu;
                model.nu1_open = model.nu;
            end
            
            model.eps1 = p.Results.eps1;
            model.eps2 = p.Results.eps2;
            model.eps3 = p.Results.eps3;
            model.xinit = reshape(p.Results.xinit,1,length(p.Results.xinit));
            model.vinit = reshape(p.Results.vinit,1,length(p.Results.vinit));
            model.tmax = p.Results.tmax;
            model.tinit = p.Results.tinit;

            
            model.yinit = [model.xinit, model.vinit];
            model.t0 = model.tinit;
            model.y0 = model.yinit;
            
            model.domain = model.checkdomain(model.xinit);
            model.grasper = checkgrasper(model.xinit);
            
        end
        
        function solve(model)
            %Initialize
            model.t0 = model.tinit;
            model.y0 = model.yinit;
            model.t = []; % Full time
            model.yext = []; % Full solution
            model.Lyp = []; % Lyapunov exponent
            model.Salt = {};
            model.t_event = [];
            model.domain_event = [];
            model.t_exit = [];
            model.domain_exit = [];
            prevdom = [];
            model.domain = model.checkdomain(model.xinit);
            model.grasper = checkgrasper(model.xinit);
            
            model.t_open_to_close = []; % Record times when switching from open to close
            model.y_open_to_close = [];
        
            model.t_close_to_open = []; % Record times when switching from close to open
            model.y_close_to_open = [];
            
            model.t_exit_a0 = []; % record times exiting wall a0=0
            model.t_enter_a0 = []; % record times entering wall a0=0
            
            model.t_exit_a2 = []; % record times exiting wall a2=0
            model.t_enter_a2 = []; % record times entering wall a2=0
   
            
            lyp_flag = strcmp(model.Lyapunov,'on');
            if lyp_flag
                model.scalefactor = -log(norm(model.vinit));
            end
            
            options0=odeset('BDF','on','RelTol',model.reltol,'AbsTol',model.abstol,'MaxStep',model.maxstep,'Events',@model.dom0_to_wall);
            options1=odeset('BDF','on','RelTol',model.reltol,'AbsTol',model.abstol,'MaxStep',model.maxstep,'Events',@model.wall1_exit);
            options2=odeset('BDF','on','RelTol',model.reltol,'AbsTol',model.abstol,'MaxStep',model.maxstep,'Events',@model.wall2_exit);
            options3=odeset('BDF','on','RelTol',model.reltol,'AbsTol',model.abstol,'MaxStep',model.maxstep,'Events',@model.wall3_exit);
            options4=odeset('BDF','on','RelTol',model.reltol,'AbsTol',model.abstol,'MaxStep',model.maxstep,'Events',@model.wall12_exit);
            options5=odeset('BDF','on','RelTol',model.reltol,'AbsTol',model.abstol,'MaxStep',model.maxstep,'Events',@model.wall13_exit);
            options6=odeset('BDF','on','RelTol',model.reltol,'AbsTol',model.abstol,'MaxStep',model.maxstep,'Events',@model.wall23_exit);
            
            while model.t0 < model.tmax
                switch model.domain
                    case 0 %interior
                        prevdom=model.domain;
                        [tnew,ynew,TE,YE,IE]=ode15s(@model.lyttle_ODE,[model.t0,model.tmax],model.y0,options0);
                        
                        if ~isempty(TE) % In some senarios, it will return two TE's: TE(1) is the initial time t0, TE(end) is the real time of event
                            TE=TE(end); YE=YE(end,:);
                        end
                        
                        model.updateSolution(tnew,ynew);
                        if lyp_flag, model.Calculate_Lyp(tnew,ynew); end
                        
                        model.updateCurrent(tnew,ynew,TE,YE);
                        
                        if ~isempty(IE), model.domain = IE(end); end                      
                        
                    case 1 % x=0 wall
                        if prevdom~=model.domain %added 08/05/2020 to record time entering a0=0 
                            model.t_enter_a0 = [model.t_enter_a0, model.t0]; 
                        end
                        model.multiplySaltation('enter',prevdom);
                        model.removeError;
                        [tnew,ynew,TE,YE,IE]=ode15s(@model.lyttle_ODE,[model.t0,model.tmax],model.y0,options1);
                        model.updateSolution(tnew,ynew);
                        if lyp_flag, model.Calculate_Lyp(tnew,ynew); end
                        
                        J0=model.jump(TE,YE,'exit',prevdom);
                        prevdom=model.domain;
                        if IE == 1
                            model.domain=0; %exiting wall 1, back to interior
                        elseif IE==2
                            model.domain=5;% entering y=0 before exiting x=0 (edge 12)
                        elseif IE==3
                            model.domain=6;% entering z=0 before exiting x=0 (edge 13)
                        elseif IE==4
                            model.domain=4; %if crossing Open/Close boundary (wall 7)
                        end
                        
                        if IE == 1
                            model.t_exit_a0 = [model.t_exit_a0, TE]; %added 08/05/2020 to record time exiting a0=0 to interior
                            
                            model.t_exit = [model.t_exit, TE];
                            model.domain_exit = [model.domain_exit, prevdom];
                            model.Jump_exit{end+1}=J0;
                        end
                        model.updateCurrent(tnew,ynew,TE,YE);
                    case 2 % y=0 wall
                        model.multiplySaltation('enter',prevdom);
                        model.removeError;
                        [tnew,ynew,TE,YE,IE]=ode15s(@model.lyttle_ODE,[model.t0,model.tmax],model.y0,options2);
                        model.updateSolution(tnew,ynew);
                        if lyp_flag, model.Calculate_Lyp(tnew,ynew); end
                        
                        J0=model.jump(TE,YE,'exit',prevdom);
                        prevdom=model.domain;
                        if IE == 1
                            model.domain=0; %exiting wall 2, back to interior
                        elseif IE==2
                            model.domain=5;% entering x=0 before exiting y=0 (edge 12)
                        elseif IE==3
                            model.domain=7;% entering z=0 before exiting y=0 (edge 23)
                        elseif IE==4
                            model.domain=4; %if crossing Open/Close boundary (wall 7)
                        end
                        
                        if IE == 1
                            model.t_exit = [model.t_exit, TE];
                            model.domain_exit = [model.domain_exit, prevdom];
                            
                            model.Jump_exit{end+1}=J0;
                        end
                        model.updateCurrent(tnew,ynew,TE,YE);
                    case 3 % z=0 wall
                        if prevdom~=model.domain % !!Not accurate:added 202104/04 to record time entering a2=0 
                            model.t_enter_a2 = [model.t_enter_a2, model.t0]; 
                        end
                        model.multiplySaltation('enter',prevdom);
                        model.removeError;
                        [tnew,ynew,TE,YE,IE]=ode15s(@model.lyttle_ODE,[model.t0,model.tmax],model.y0,options3);
                        model.updateSolution(tnew,ynew);
                        if lyp_flag, model.Calculate_Lyp(tnew,ynew); end
                        
                        J0=model.jump(TE,YE,'exit',prevdom);
                        prevdom=model.domain;
                        if IE == 1
                            model.domain=0; %exiting wall 3, back to interior
                        elseif IE==2
                            model.domain=6;% entering x=0 before exiting z=0 (edge 13)
                        elseif IE==3
                            model.domain=7;% entering y=0 before exiting z=0 (edge 23)
                        elseif IE==4
                            model.domain=4; %if crossing Open/Close boundary (wall 7)
                        end
                        
                        if IE == 1
                            
                            model.t_exit_a2 = [model.t_exit_a2, TE]; % added 2021/04/04
                            
                            model.t_exit = [model.t_exit, TE];
                            model.domain_exit = [model.domain_exit, prevdom];
                            
                            model.Jump_exit{end+1}=J0;
                        end
                        
                        model.updateCurrent(tnew,ynew,TE,YE);
                    case 4 % Grasper change
                        model.multiplySaltation('enter',prevdom);
                        J0=model.jump(TE,YE,'exit',prevdom);
                        model.domain=prevdom; %domain won't change when crossing O/C boundary
                        model.grasper=1-model.grasper; %switch grasper status
                        
                        if model.grasper == 1 % grasper switches from open (0) to close (1)
                            model.t_open_to_close = [model.t_open_to_close, model.t0];
                            model.y_open_to_close = [model.y_open_to_close; model.y0];
                        elseif model.grasper == 0 % grasper switches from close (1) to open (0)
                            model.t_close_to_open = [model.t_close_to_open, model.t0];
                            model.y_close_to_open = [model.y_close_to_open; model.y0];
                        end
                            
                        model.t_exit = [model.t_exit, TE];
                        model.domain_exit = [model.domain_exit, 4];
                        model.Jump_exit{end+1}=J0;
                    case 5 % x=y=0 wall
                        model.multiplySaltation('enter',prevdom);
                        model.removeError;
                        [tnew,ynew,TE,YE,IE]=ode15s(@model.lyttle_ODE,[model.t0,model.tmax],model.y0,options4);
                        model.updateSolution(tnew,ynew);
                        if lyp_flag, model.Calculate_Lyp(tnew,ynew); end
                        
                        J0=model.jump(TE,YE,'exit',prevdom);
                        prevdom=model.domain;
                        if IE == 1
                            model.domain=2; % exiting x=0 first
                            model.t_exit_a0 = [model.t_exit_a0, TE]; %added to record time exiting a0=0 to interior
                   
                        elseif IE == 2
                            model.domain=1; % exiting y=0 first
                        elseif IE == 3
                            model.domain=4; % crossing the close/open boundary
                        end
                        
                        if IE~=4
                            model.t_exit = [model.t_exit, TE];
                            model.domain_exit = [model.domain_exit, prevdom];
                            model.Jump_exit{end+1}=J0;
                        end
                        model.updateCurrent(tnew,ynew,TE,YE);
                    case 6 % x=z=0 wall
                        model.multiplySaltation('enter',prevdom);
                        model.removeError;
                        [tnew,ynew,TE,YE,IE]=ode15s(@model.lyttle_ODE,[model.t0,model.tmax],model.y0,options5);
                        model.updateSolution(tnew,ynew);
                        if lyp_flag, model.Calculate_Lyp(tnew,ynew); end
                        
                        J0=model.jump(TE,YE,'exit',prevdom);
                        prevdom=model.domain;
                        if IE == 1
                            model.domain=3; % exiting x=0 first
                        elseif IE == 2
                            model.domain=1; % exiting z=0 first
                            
                            model.t_exit_a2 = [model.t_exit_a2, TE]; % added 2021/04/04
                        elseif IE == 3
                            model.domain=4; % crossing the close/open boundary
                        end
                        
                        if IE~=4
                            model.t_exit = [model.t_exit, TE];
                            model.domain_exit = [model.domain_exit, prevdom];
                            model.Jump_exit{end+1}=J0;
                        end
                        model.updateCurrent(tnew,ynew,TE,YE);
                    case 7 % y=z=0 wall
                        model.multiplySaltation('enter',prevdom);
                        model.removeError;
                        [tnew,ynew,TE,YE,IE]=ode15s(@model.lyttle_ODE,[model.t0,model.tmax],model.y0,options6);
                        model.updateSolution(tnew,ynew);
                        if lyp_flag, model.Calculate_Lyp(tnew,ynew); end
                        
                        J0=model.jump(TE,YE,'exit',prevdom);
                        prevdom=model.domain;
                        if IE == 1
                            model.domain=3; % exiting y=0 first
                        elseif IE == 2
                            model.domain=2; % exiting z=0 first
                            
                            model.t_exit_a2 = [model.t_exit_a2, TE]; % added 2021/04/04
                        elseif IE == 3
                            model.domain=4; % crossing the close/open boundary
                        end
                        
                        if IE~=4
                            model.t_exit = [model.t_exit, TE];
                            model.domain_exit = [model.domain_exit, prevdom];
                            model.Jump_exit{end+1}=J0;
                        end
                        model.updateCurrent(tnew,ynew,TE,YE);
                end
            end
        end
        
        function find_prc(model, z0)
            
            if nargin < 2
                z0 = [1 0 0 0 0 0];
            end
            
            model.prct=[];
            model.prc=[];
            opts=odeset('BDF','on','RelTol',model.reltol,'AbsTol',model.abstol,'Events',@model.exit_wall);
           
            [model.tspan, Ind] = unique(wrev(model.t),'stable');
            if isempty(model.tspan)
                error('Solve the model first before calling find_prc!');
            end
            ymat = model.yext(wrev(Ind),1:8);
            
            dom = 0;
            counter = 0;
            TE = inf;
            while true
                switch dom
                    case 0
                        T = model.tspan(model.tspan <= TE);
                        if T == 0
                            break;
                        end
                        [tnew,znew,TE,YE,IE]=ode15s(@model.lyttle_ODE_prc,T,z0,opts,ymat);
                        model.prct = [model.prct;tnew];
                        model.prc = [model.prc;znew];
                        dom=1;
                        if ~isempty(IE)
                            IE = IE(end);
                            TE = TE(end); 
                        end
                        if counter >= numel(model.t_exit)
                            break;
                        end
                    case 1
                        J=model.Jump_exit{IE};
                        z0 = znew(end,1:6)*J';
                        counter = counter + 1;
                        dom=0;                        
                end
            end
        end
        
        function plot_prc(model)
            figure
            subplot(2,1,1)
            plot(model.prct,model.prc(:,1:3),'linewidth',2)
            legend('$z_{1}$','$z_{2}$','$z_{3}$','interpreter','latex','fontsize',25)
            xlim([0 model.tmax])
            ylim([0 5e+4])
            model.draw_wall_closing
            
            subplot(2,1,2)
            plot(model.prct,model.prc(:,4:6),'linewidth',2)
            legend('$z_{4}$','$z_{5}$','$z_{6}$','interpreter','latex','fontsize',25)
            xlim([0 model.tmax])
            ylim([-4 6])
            model.draw_wall_closing 
        end
        
        function plot(model)
            figure
            subplot(1,2,1)
            plot(model.t,model.yext(:,1),model.t,model.yext(:,2),model.t,model.yext(:,3),model.t,model.yext(:,4),model.t,model.yext(:,5),model.t,model.yext(:,6),'linewidth',2)
            axis([0 model.tmax -0.1 1.1])
            legend('$a_0$','$a_1$','$a_2$','$u_0$','$u_1$','$x_r$','Location','southwest','interpreter','latex')
            model.draw_wall_closing
            
            
            subplot(1,2,2)
            plot3(model.yext(:,1),model.yext(:,2),model.yext(:,3),'linewidth',2)
            axis([-0.1 1.1 -0.1 1.1 -0.1 1.1])
            xlabel('$a_0$','interpreter','latex','fontsize',25)
            ylabel('$a_1$','interpreter','latex','fontsize',25)
            zlabel('$a_2$','interpreter','latex','fontsize',25,'rot',0)
            title('Phase plane')
            
            if strcmp(model.Lyapunov,'on')
                figure
                plot(model.t,model.Lyp,'*')
                xlim([0 model.tmax])
                title('Lyapunov exponent')
            end
            
        end
        
        % plot variational dynamics 
        function plot_var(model)
            figure
            subplot(2,1,1)
            plot(model.t,model.yext(:,9:11),'linewidth',2)
            
            xlim([0 model.tmax])
            %             ylim([-6 6])
            set(gca,'FontSize',18)
            model.draw_wall_closing
            legend('$\gamma_{1,a_0}$','$\gamma_{1,a_1}$','$\gamma_{1,a_2}$','interpreter','latex','fontsize',15)
            
            subplot(2,1,2)
            plot(model.t,model.yext(:,12:14),'linewidth',2)
            % hold on
            % plot(model.t,model.fvar(model.yext(:,4),model.yext(:,5),model.yext(:,6),...
            %                 model.yext(:,12),model.yext(:,13),model.yext(:,14))/model.br,'linewidth',2)
            
            % legend('$\gamma_{1,u_0}$','$\gamma_{1,u_1}$','$\gamma_{1,x_r}$','$\Delta F_m$','interpreter','latex','fontsize',25)
            
            xlim([0 model.tmax])
            %             ylim([-4 2])
            xlabel('$\rm time$','interpreter','latex','fontsize',30)
            set(gca,'FontSize',18)
            model.draw_wall_closing
            legend('$\gamma_{1,u_0}$','$\gamma_{1,u_1}$','$\gamma_{1,x_r}$','interpreter','latex','fontsize',15)
        end
        
        function plot_var_horizontal(model)
            figure
            set(gcf,'Position',[500 800 1200 400])
            subplot(1,2,1)
            plot(model.t,model.yext(:,9:11),'linewidth',2)           
            xlim([0 model.tmax])
            %             ylim([-6 6])
            xlabel('$\rm time$','interpreter','latex','fontsize',30)
            set(gca,'FontSize',18)
            model.draw_wall_closing
            legend('$a_0$','$a_1$','$a_2$','interpreter','latex','fontsize',15)
            
            subplot(1,2,2)
            plot(model.t,model.yext(:,12:14),'linewidth',2)
            hold on
            plot(model.t,model.fvar(model.yext(:,4),model.yext(:,5),model.yext(:,6),...
                              model.yext(:,12),model.yext(:,13),model.yext(:,14)),'Color',[0.5 0.5 0.5],'linewidth',2)
            
            xlim([0 model.tmax])
            xlabel('$\rm time$','interpreter','latex','fontsize',30)
            set(gca,'FontSize',18)
            model.draw_wall_closing
            legend('$u_0$','$u_1$','$x_r$','interpreter','latex','fontsize',15)
        end
        
        % plot the integrand in the expression for -d(Delta x)/deps
        function plot_dx_int(model)
            
            u0 = model.yext(:,4); u1 = model.yext(:,5); xr = model.yext(:,6);
            du0 = model.yext(:,12); du1 = model.yext(:,13); dxr = model.yext(:,14);
            
            term1 = -(u0/model.w0).*model.k0*phiprime((model.c0-xr)/model.w0);
            term2 = -(u1/model.w1).*model.k1*phiprime((model.c1-xr)/model.w1);
            term3 = model.k0*phi((model.c0-xr)/model.w0);
            term4 = model.k1*phi((model.c1-xr)/model.w1);
            
            figure
            subplot(2,1,1)
            plot(model.t, term1.*dxr,'linewidth',2)          
            hold on
            plot(model.t, term2.*dxr,'linewidth',2)               
            plot(model.t, term3.*du0,'linewidth',2)            
            plot(model.t, term4.*du1,'linewidth',2)           
            legend('$-\frac{u_0}{w_0}\phi\prime dx_r$','$\frac{u_1}{w_1}\phi\prime dx_r$','$\phi du_0$','$-\phi du_1$','interpreter','latex','fontsize',25)
            xlim([0 model.tmax])
            xlabel('$\rm time$','interpreter','latex','fontsize',30)
            set(gca,'FontSize',18)
            model.draw_wall_closing 
            
            subplot(2,1,2)
            plot(model.t, (term1+term2).*dxr,'linewidth',2)          
            hold on                   
            plot(model.t, term3.*du0+term4.*du1,'linewidth',2)            
            plot(model.t, (term1+term2).*dxr + term3.*du0+term4.*du1,'linewidth',2)         
            legend('$-\frac{u_0}{w_0}\phi\prime dx_r+\frac{u_1}{w_1}\phi\prime dx_r$','$\phi du_0-\phi du_1$','all','interpreter','latex','fontsize',25)
            xlim([0 model.tmax])
            xlabel('$\rm time$','interpreter','latex','fontsize',30)
            set(gca,'FontSize',18)
            model.draw_wall_closing 
        end
        
        function draw_wall_closing(model, yrange)
            if ~exist('yrange', 'var')
                yrange = ylim;              % by default use current ylim
            end
            close = ...                    % logical array for when any of these are true:
                     (model.yext(:,2)+model.yext(:,3)>0.5);      
            values = zeros(size(close));   % rectangle height as a function of time
            values(~close) = yrange(1);    % set low value
            values( close) = yrange(2);    % set high value
            hold on;                        % don't remove existing plot elements
            h = area(model.t, values, ...   % draw rectangles
                yrange(1), ...              % fill from bottom of plot instead of from 0
                'FaceColor', 'k', ...       % black
                'FaceAlpha', 0.1, ...       % transparent
                'LineStyle', 'none', ...    % no border
                'ShowBaseLine', 'off', ...  % no baseline
                'HandleVisibility', 'off'); % prevent this object from being added to legends
            uistack(h, 'bottom');           % put the rectangles behind all other plot elements
        end
        
        function T = findPeriod(model,minperiod,maxperiod)
            % Function to estimate the period of the model
            % Need to input a smallest possible period and a largest
            % possible period; the input order doesn't matter because the
            % if-statement below will swap the two if max is less than min
            if minperiod < maxperiod
                L = minperiod;
                R = maxperiod;
            else
                L = maxperiod;
                R = minperiod;
            end
            
            M = nan;
            
            maxsearch = 20; % Max number of searches
            target = 1e-5; % Accuracy of the period
            search = 0;
            initSol = model.yinit(1:6);
            while search < maxsearch && abs(R-L) > target
                model.tmax = L;
                model.solve;
                Lsol = model.yext(end,1:6);
                Lsign = sign(Lsol - initSol); % The sign is a good indication for whether L is over a period or within a period
                
                model.tmax = R;
                model.solve;
                Rsol = model.yext(end,1:6);
                Rsign = sign(Rsol - initSol);
                
                M = (L+R)/2; % Pick the mid-point
                model.tmax = M;
                model.solve;
                Msol = model.yext(end,1:6);
                Msign = sign(Msol - initSol);
                
                search = search + 1;
                
                if sum(Lsign == Msign) < sum(Rsign == Msign)
                    R = M; % If R and M are on the same side, assign new R
                else
                    L = M; % If L and M are on the same side, assign new L
                end
                fprintf('.');
            end
            
            if search == maxsearch
                warning('findPeriod: maxtrial reached. Accurate period cannot be found, try different initial guesses.');
            end
            T = M;
        end
    end
    
    methods(Access = public)
        %% ODEs
        function dydt = lyttle_ODE(model,~,y,domain_overload,grasper_overload)
            if nargin >3
                ODEdomain = domain_overload;
            else
                ODEdomain = model.domain;
            end
            
            if nargin >4
                ODEgrasper = grasper_overload;
            else
                ODEgrasper = model.grasper;
            end
            
            fsw = y(8);
            dydt=zeros(14,1);
            
            % Default system
            dydt(1)=((y(1)*(1-y(1)-model.gamma*y(2))+model.mu+model.eps1*(y(6)-model.s1)*model.sig1))/model.tau_a;
            dydt(2)=((y(2)*(1-y(2)-model.gamma*y(3))+model.mu+model.eps2*(y(6)-model.s2)*model.sig2))/model.tau_a;
            dydt(3)=((y(3)*(1-y(3)-model.gamma*y(1))+model.mu+model.eps3*(y(6)-model.s3)*model.sig3))/model.tau_a;
            % DE for u0
            dydt(4)=((y(1)+y(2))*model.umax-y(4))/model.tau_m; % eqn (7) in Lyttle et al
            % DE for u1
            dydt(5)=((y(3)*model.umax-y(5))/model.tau_m); % eqn (8) in Lyttle et al
            % DE for xr
            dydt(6)=(model.fmusc(y(4),y(5),y(6))+fsw)/model.br;
            % DE for seaweed
            dydt(7)=dydt(6); % seaweed movement
            % DE for parameter
            dydt(8)=0; % force of seaweed is a parameter
            
            % DE for variational problem: interior case
            dydt(9)=(1-2*y(1)-model.gamma*y(2))*y(9)/model.tau_a - y(1)*model.gamma*y(10)/model.tau_a + model.eps1*model.sig1*y(14)/model.tau_a;
            dydt(10)=(1-2*y(2)-model.gamma*y(3))*y(10)/model.tau_a - y(2)*model.gamma*y(11)/model.tau_a + model.eps2*model.sig2*y(14)/model.tau_a;
            dydt(11)=(1-2*y(3)-model.gamma*y(1))*y(11)/model.tau_a - y(3)*model.gamma*y(9)/model.tau_a + model.eps3*model.sig3*y(14)/model.tau_a;
            dydt(12)=model.umax*(y(9)+y(10))/model.tau_m - y(12)/model.tau_m;
            dydt(13)=model.umax*y(11)/model.tau_m - y(13)/model.tau_m;
            dydt(14)=(model.fmusc(y(12),y(13),y(6)) + model.J66(y(4),y(5),y(6))*y(14))/model.br;
            
            switch ODEdomain
                case 1
                    % DE for a0 when x = y(1) = 0
                    dydt(1)=max(0,dydt(1));
                    dydt(9)=0;
                    dydt(11)=(1-2*y(3))*y(11)/model.tau_a + model.eps3*model.sig3*y(14)/model.tau_a;
                    dydt(12)=model.umax*y(10)/model.tau_m - y(12)/model.tau_m;
                case 2
                    % DE for a1 when y = y(2) = 0
                    dydt(2)=max(0,dydt(2));
                    dydt(9)=(1-2*y(1))*y(9)/model.tau_a + model.eps1*model.sig1*y(14)/model.tau_a;
                    dydt(10)=0;
                    dydt(12)=model.umax*(y(9))/model.tau_m - y(12)/model.tau_m;
                case 3
                    % DE for a2 when z = y(3) = 0
                    dydt(3)=max(0,dydt(3));
                    dydt(10)=(1-2*y(2)-model.gamma*0)*y(10)/model.tau_a + model.eps2*model.sig2*y(14)/model.tau_a;
                    dydt(11)=0;
                    dydt(13)= - y(13)/model.tau_m;
                case 5
                    % DE for a0 and a1 when x=y=0
                    dydt(1)=max(0,dydt(1));
                    dydt(2)=max(0,dydt(2));
                    dydt(9)=0;
                    dydt(10)=0;
                    dydt(11)=(1-2*y(3)-model.gamma*0)*y(11)/model.tau_a + model.eps3*model.sig3*y(14)/model.tau_a;
                    dydt(12)=- y(12)/model.tau_m;
                case 6
                    % DE for a0 and a2 when x=z=0
                    dydt(1)=max(0,dydt(1));
                    dydt(3)=max(0,dydt(3));
                    dydt(9)=0;
                    dydt(10)=(1-2*y(2)-model.gamma*0)*y(10)/model.tau_a + model.eps2*model.sig2*y(14)/model.tau_a;
                    dydt(11)=0;
                    dydt(12)=model.umax*(y(10))/model.tau_m - y(12)/model.tau_m;
                    dydt(13)= - y(13)/model.tau_m;
                case 7
                    % DE for a1 and a2 when y=z=0
                    dydt(2)=max(0,dydt(2));
                    dydt(3)=max(0,dydt(3));
                    dydt(9)=(1-2*y(1)-model.gamma*0)*y(9)/model.tau_a + model.eps1*model.sig1*y(14)/model.tau_a;
                    dydt(10)=0;
                    dydt(11)=0;
                    dydt(12)=model.umax*(y(9))/model.tau_m - y(12)/model.tau_m;
                    dydt(13)= - y(13)/model.tau_m;
            end
            
            if ODEgrasper == 0
                dydt(6)=(model.fmusc(y(4),y(5),y(6)))/model.br;
                dydt(7)=0;
            end
            
            % add nonhomogeneous terms to variational problem for sustained perturbation
            % nu*F(x(t)) + DFeps/Deps; DF/Deps=[0;...;0; 1/br] during closing phase where the
            % perturbation is fsw -> fsw + eps
            
            dydt(9:14) = dydt(9:14) + model.addon(ODEgrasper, dydt); % modify when computing iSRC
        end
        
        
        function dzdt = lyttle_ODE_prc(model,t,z,ymat)
           
%             y=periodic_solution(t); % define po as a function y=@t y=y(find(y(1)==t)
            
%           fsw = y(8);
            dzdt=zeros(6,1);
            y = interp1(model.tspan,ymat,t);
            
            DF=zeros(6,6);
            % Jacobian matrix: interior case
            DF(1,:)=[(1-2*y(1)-model.gamma*y(2))/model.tau_a, -y(1)*model.gamma/model.tau_a, 0, 0, 0, model.eps1*model.sig1/model.tau_a];
            DF(2,:)=[0, (1-2*y(2)-model.gamma*y(3))/model.tau_a, -y(2)*model.gamma/model.tau_a, 0, 0, model.eps2*model.sig2/model.tau_a];
            DF(3,:)=[-y(3)*model.gamma/model.tau_a, 0, (1-2*y(3)-model.gamma*y(1))/model.tau_a, 0, 0, model.eps3*model.sig3/model.tau_a];
            DF(4,:)=[model.umax/model.tau_m, model.umax/model.tau_m, 0, -1/model.tau_m, 0, 0];
            DF(5,:)=[0, 0, model.umax/model.tau_m, 0, -1/model.tau_m, 0];
            DF(6,:)=[0, 0, 0, model.fmusc(1,0,y(6))/model.br, model.fmusc(0,1,y(6))/model.br, model.J66(y(4),y(5),y(6))/model.br];
            
            switch model.checkdomain(y)
                case 1
                    % DE for a0 when x = y(1) = 0, dydt(9)=0;
%                     dydt(1)=max(0,dydt(1));
                    DF(1,:)=[0, 0, 0, 0, 0, 0];
                    DF(3,:)=[0, 0, (1-2*y(3))/model.tau_a, 0, 0, model.eps3*model.sig3/model.tau_a];
                    DF(4,:)=[0, model.umax/model.tau_m, 0, -1/model.tau_m, 0, 0];
                case 2
                    % DE for a1 when y = y(2) = 0, dydt(10)=0;
%                     dydt(2)=max(0,dydt(2));
                    DF(1,:)=[(1-2*y(1))/model.tau_a, 0, 0, 0, 0, model.eps1*model.sig1/model.tau_a];
                    DF(2,:)=[0, 0, 0, 0, 0, 0];
                    DF(4,:)=[model.umax/model.tau_m, 0, 0, -1/model.tau_m, 0, 0];
                    
                case 3
                    % DE for a2 when z = y(3) = 0, dydt(11)=0;
%                     dydt(3)=max(0,dydt(3));
                    DF(2,:)=[0, (1-2*y(2))/model.tau_a, 0, 0, 0, model.eps2*model.sig2/model.tau_a];
                    DF(3,:)=[0, 0, 0, 0, 0, 0];
                    DF(5,:)=[0, 0, 0, 0, -1/model.tau_m, 0];
                    
                case 5
                    % DE for a0 and a1 when x=y=0, dydt(9)==dydt(10)=0;
%                     dydt(1)=max(0,dydt(1));
%                     dydt(2)=max(0,dydt(2));
                    DF(1,:)=[0, 0, 0, 0, 0, 0];
                    DF(2,:)=[0, 0, 0, 0, 0, 0];
                    DF(3,:)=[0, 0, (1-2*y(3))/model.tau_a, 0, 0, model.eps3*model.sig3/model.tau_a];
                    DF(4,:)=[0, 0, 0, -1/model.tau_m, 0, 0];
                    
                case 6
                    % DE for a0 and a2 when x=z=0, dydt(9)=dydt(11)=0;
%                     dydt(1)=max(0,dydt(1));
%                     dydt(3)=max(0,dydt(3));
                    DF(1,:)=[0, 0, 0, 0, 0, 0];
                    DF(2,:)=[0, (1-2*y(2))/model.tau_a, 0, 0, 0, model.eps2*model.sig2/model.tau_a];
                    DF(3,:)=[0, 0, 0, 0, 0, 0];
                    DF(4,:)=[0, model.umax/model.tau_m, 0, -1/model.tau_m, 0, 0];
                    DF(5,:)=[0, 0, 0, 0, -1/model.tau_m, 0];
                    
                case 7
                    % DE for a1 and a2 when y=z=0, dydt(10)=dydt(11)=0;
%                     dydt(2)=max(0,dydt(2));
%                     dydt(3)=max(0,dydt(3));
                    DF(1,:)=[(1-2*y(1))/model.tau_a, 0, 0, 0, 0, model.eps1*model.sig1/model.tau_a];
                    DF(2,:)=[0, 0, 0, 0, 0, 0];
                    DF(3,:)=[0, 0, 0, 0, 0, 0];
                    DF(4,:)=[model.umax/model.tau_m, 0, 0, -1/model.tau_m, 0, 0];
                    DF(5,:)=[0, 0, 0, 0, -1/model.tau_m, 0];
            end
            
            dzdt(1:6,:)=-DF'*[z(1); z(2); z(3); z(4); z(5); z(6)];
            
        end
        
    end   
    
    methods(Hidden)
        %% Event functions
        function [value,isterminal,direction]=dom0_to_wall(model,~,y)
            value=[...
                y(1);...  % when x crosses 0 from above(wall 1)
                y(2);... % when y crosses 0 from above(wall 2)
                y(3);...  % when z crosses 0 from above(wall 3)
                y(2)+y(3)-0.5]; % when grasper is going to change (wall 7)
            isterminal=[1;1;1;1]; % stop integration and return
            direction=[-1;-1;-1;0]; % "value" should be increasing/decreasing
        end
        
        function [value,isterminal,direction]=wall1_exit(model,~,y)
            % when the *unconstrained* value of dx/dt increases through zero;
            % or when a second wall is hitted (y or z decreases through 0);
            % or when the trajectory crosses the Open/Close boundary y+z=0.5,
            % return exit event for wall1, x=0
            dummy = 0; % a dummy variable with no actual usage
            dydt=model.lyttle_ODE(dummy,y,0);
            y(1)=0;
            value=[dydt(1),y(2),y(3),y(2)+y(3)-0.5]; % rate of change in x
            isterminal=[1,1,1,1]; % stop integration and return
            direction=[1,-1,-1,0]; % first "value" should be increasing
        end
        
        function [value,isterminal,direction]=wall2_exit(model,~,y)
            % when the *unconstrained* value of dy/dt increases through zero,
            % or when a second wall is hitted (x or z decreases through 0);
            % or when the trajectory crosses the Open/Close boundary y+z=0.5,
            %return exit event for wall3, y=0
            dummy = 0; % a dummy variable with no actual usage
            dydt=model.lyttle_ODE(dummy,y,0);
            y(2)=0;
            value=[dydt(2),y(1),y(3),y(2)+y(3)-0.5]; % rate of change in y
            isterminal=[1,1,1,1]; % stop integration and return
            direction=[1,-1,-1,0]; % "value" should be increasing
        end
        
        function [value,isterminal,direction]=wall3_exit(model,~,y)
            % when the *unconstrained* value of dz/dt increases through zero,
            % or when a second wall is hitted (x or y decreases through 0);
            % or when the trajectory crosses the Open/Close boundary y+z=0.5,
            % return exit event for wall5, z=0
            dummy = 0; % a dummy variable with no actual usage
            dydt=model.lyttle_ODE(dummy,y,0);
            y(3)=0;
            value=[dydt(3),y(1),y(2),y(2)+y(3)-0.5]; % rate of change in z
            isterminal=[1,1,1,1]; % stop integration and return
            direction=[1,-1,-1,0]; % "value" should be increasing
        end
        
        function [value,isterminal,direction]=wall12_exit(model,~,y)
            % when the *unconstrained* value of dx/dt or dy/dt increases through zero,
            % or when the trajectory crosses the Open/Close boundary y+z=0.5,
            % return exit event for edge of wall 1 and wall2, x=y=0
            
            dummy = 0; % a dummy variable with no actual usage
            dydt=model.lyttle_ODE(dummy,y,0);
            y(1)=0;y(2)=0;
            value=[dydt(1),dydt(2),y(2)+y(3)-0.5]; % rate of change in x
            isterminal=[1,1,1]; % stop integration and return
            direction=[1,1,0]; % "value" should be decreasing
        end
        
        function [value,isterminal,direction]=wall13_exit(model,~,y)
            % when the *unconstrained* value of dx/dt or dz/dt increases through zero,
            % or when the trajectory crosses the Open/Close boundary y+z=0.5,
            % return exit event for edge of wall 1 and wall3, x=z=0
            
            dummy = 0; % a dummy variable with no actual usage
            dydt=model.lyttle_ODE(dummy,y,0);
            y(1)=0;y(3)=0;
            value=[dydt(1),dydt(3),y(2)+y(3)-0.5]; % rate of change in x
            isterminal=[1,1,1]; % stop integration and return
            direction=[1,1,0]; % "value" should be decreasing
        end
        
        function [value,isterminal,direction]=wall23_exit(model,~,y)
            % when the *unconstrained* value of dx/dt or dy/dt increases through zero,
            % or when the trajectory crosses the Open/Close boundary y+z=0.5,
            % return exit event for edge of wall 2 and wall 3, x=y=0
            
            dummy = 0; % a dummy variable with no actual usage
            dydt=model.lyttle_ODE(dummy,y,0);
            y(2)=0;y(3)=0;
            value=[dydt(2),dydt(3),y(2)+y(3)-0.5]; % rate of change in x
            isterminal=[1,1,1]; % stop integration and return
            direction=[1,1,0]; % "value" should be decreasing
        end
        
        function [value,isterminal,direction]=exit_wall(model,t,~,~)
            value = model.t_exit - t;
            isterminal=ones(size(model.t_exit));
            direction=ones(size(model.t_exit));
        end
    end
    
    methods(Hidden)
        % Helpers
        function Calculate_Lyp(model,tnew,ynew)
            L=(model.scalefactor+0.5*log(sum(ynew(:,9:14).^2,2)))./tnew;
            model.Lyp = [model.Lyp; L];
            model.scalefactor=model.scalefactor+log(norm(ynew(end,9:14)));
        end
        
        function updateSolution(model,tnew,ynew)
            model.t = [model.t;tnew];
            model.yext = [model.yext;ynew];
        end
        
        function updateCurrent(model,tnew,ynew,TE,YE)
            if ~isempty(TE)
                model.t0 = TE(end);
            else
                model.t0 = max(tnew);
            end
            if ~isempty(TE)
                model.y0 = YE(end,:);
            else
                model.y0 = ynew(end,:);
            end
            
            model.removeError();
        end
        
        function h = addon(model, ODEgrasper, dydt)
            % nonhomogeneous terms nu*F(x(t)) + DFeps/Deps for iSRC equation
            
            % if nu is empty, run the forward variational equation with
            % addon = (partial F/ partial eps)
            if isempty(model.nu) 
               h = zeros(6,1);
            if ODEgrasper == 1 % if grasper is closed
                h(6) = h(6) + 1/model.br;
            end
            return
            end
                        
            % if both nu's are zero, then the perturbation is instantaneous: nonhomogeneous addon is zero
            if (model.nu1_close == 0) && (model.nu1_open == 0) 
                h = 0;
            end 
            
            % if it is a uniformly perturbed (not piecewise) problem and nu's are not 0
            if ~model.isPiecewise && (model.nu1_close ~= 0)
                h = model.nu1_close*dydt(1:6);
                if ODEgrasper == 1 % if grasper is closed
                    h(6) = h(6) + 1/model.br;
                end
            end
            
            % if it is a piecewisely perturbed problem when the perturbation only exists in the closed domain
            if model.isPiecewise && (model.nu1_close ~=0) && (model.nu1_open ~=0)
                if ODEgrasper == 1 % if grasper is closed
                    h = model.nu1_close*dydt(1:6);
                    h(6) = h(6) + 1/model.br; % DF_eps/Deps only exists in the closed phase
                else
                    h = model.nu1_open*dydt(1:6);
                end
            end
            
            
            
        end
        
        
        function J1=jump(model,TE,YE,flag,prevdom) % multiply fundMatrix by saltation matrix S
            
            dom=model.domain;
            I=eye(6);
            J1=[];
            if ~isempty(TE)
                switch dom
                    case 1
                        if strcmp(flag,'enter')
                            J1=eye(6);%jump matrix when entering wall 1 x=0
                        end
                        if strcmp(flag,'exit')
                            J1=eye(6);
                            J1(:,1)=[0 0 0 0 0 0]';%inverse of jump matrix when exit wall 1
                        end
                        
                    case 2
                        if strcmp(flag,'enter')
                            J1=eye(6); %jump matrix when entering wall 2 y=0
                        end
                        if strcmp(flag,'exit')
                            J1=eye(6);
                            J1(:,2)=[0 0 0 0 0 0]';%inverse of jump matrix when exit wall 2
                        end
                    case 3
                        if strcmp(flag,'enter')
                            J1=eye(6); %jump matrix when entering wall 3
                        end
                        if strcmp(flag,'exit')
                            J1=eye(6);
                            J1(:,3)=[0 0 0 0 0 0]';%inverse of jump matrix when exit wall 3
                        end
                    case 4 % wall 4 y+z=0.5
                        dydtdom=model.lyttle_ODE(TE,YE,prevdom,model.grasper); %dydt(t-)
                        dydtdom=dydtdom(1:6);
                        dydtswitch=model.lyttle_ODE(TE,YE,prevdom,1-model.grasper); %dydt(t+)
                        dydtswitch=dydtswitch(1:6);
                        A1=[dydtswitch'; I(1,:); I(4:6,:);0 1 -1 0 0 0];
                        B1=[dydtdom'; I(1,:); I(4:6,:);0 1 -1 0 0 0];
                        J1=A1\B1; %jump matrix when entering wall 3
                        J1=inv(J1); % inverse of jump matrix when entering wall 3
                    case 5
                        if strcmp(flag,'enter')
                            J1=eye(6); %jump matrix when entering wall 12 x=y=0
                        end
                        if strcmp(flag,'exit')
                            J1=eye(6);
                            J1(:,1)=[0 0 0 0 0 0]';
                            J1(:,2)=[0 0 0 0 0 0]'; %inverse of jump matrix when exit wall 4
                        end
                    case 6
                        if strcmp(flag,'enter')
                            J1=eye(6); %jump matrix matrix when entering wall 13:x=z=0
                        end
                        if strcmp(flag,'exit')
                            J1=eye(6);
                            J1(:,1)=[0 0 0 0 0 0]';
                            J1(:,3)=[0 0 0 0 0 0]'; %inverse of jump matrix when exit wall 4
                        end
                    case 7
                        if strcmp(flag,'enter')
                            J1=eye(6); %jump matrix when entering wall 23:y=z=0
                        end
                        if strcmp(flag,'exit')
                            J1=eye(6);
                            J1(:,2)=[0 0 0 0 0 0]';
                            J1(:,3)=[0 0 0 0 0 0]'; %jump matrix when exit wall 4
                        end
                        
                end
            end
        end
        
        function S0=saltation(model,TE,YE,flag,prevdom) % multiply fundMatrix by saltation matrix S
            
            dom=model.domain;
            na=[1,0,0,0,0,0]; % na is the normal vector to wall 1: x=0
            nb=[0,1,0,0,0,0]; % nb is the normal vector to wall 2 y=0
            nc=[0,0,1,0,0,0]; % nc is the normal vector to wall 3: z=0
            nab=[1,1,0,0,0,0]; % na is the normal vector to wall 12: x=y=0
            nac=[1,0,1,0,0,0]; % nb is the normal vector to wall 13 x=z=0
            nbc=[0,1,1,0,0,0]; % nc is the normal vector to wall 23: y=z=0
            nd=[0,1,1,0,0,0]; % nd is the normal vector to wall 7: y+z=0.5
            %YE=YE(:,1:8)';
            S1=[];
            if ~isempty(TE)
                dydt0=model.lyttle_ODE(TE,YE,0);
                dydt0=dydt0(1:6);
                dydtdom=model.lyttle_ODE(TE,YE,dom);
                dydtdom=dydtdom(1:6);
                switch dom
                    case 1
                        if strcmp(flag,'enter')
                            S1=eye(6)+(dydtdom-dydt0)*na/(na*dydt0); %saltation matrix when entering wall 1 x=0
                        end
                        if strcmp(flag,'exit')
                            S1=eye(6);%saltation matrix when exit wall 1
                        end
                        
                    case 2
                        if strcmp(flag,'enter')
                            S1=eye(6)+(dydtdom-dydt0)*nb/(nb*dydt0); %saltation matrix when entering wall 2 y=0
                        end
                        if strcmp(flag,'exit')
                            S1=eye(6);%saltation matrix when exit wall 2
                            %                 S1=eye(6)+(dydt0-dydtdom)*nb/(nb*dydtdom);
                        end
                    case 3
                        if strcmp(flag,'enter')
                            S1=eye(6)+(dydtdom-dydt0)*nc/(nc*dydt0); %saltation matrix when entering wall 3
                        end
                        if strcmp(flag,'exit')
                            S1=eye(6);%saltation matrix when exit wall 3
                        end
                    case 4 % wall 4 y+z=0.5
                        dydtdom=model.lyttle_ODE(TE,YE,prevdom,model.grasper); %dydt(t-)
                        dydtdom=dydtdom(1:6);
                        dydtswitch=model.lyttle_ODE(TE,YE,prevdom,1-model.grasper); %dydt(t+)
                        dydtswitch=dydtswitch(1:6);
                        S1=eye(6)+(dydtswitch-dydtdom)*nd/(nd*dydtdom);
                    case 5
                        dydtprevdom=model.lyttle_ODE(TE,YE,prevdom);
                        dydtprevdom=dydtprevdom(1:6);
                        if strcmp(flag,'enter')
                            S1=eye(6)+(dydtdom-dydtprevdom)*nab/(nab*dydtprevdom); %saltation matrix when entering wall 12 x=y=0
                        end
                        if strcmp(flag,'exit')
                            S1=eye(6);%saltation matrix when exit wall 4
                        end
                    case 6
                        dydtprevdom=model.lyttle_ODE(TE,YE,prevdom);
                        dydtprevdom=dydtprevdom(1:6);
                        if strcmp(flag,'enter')
                            S1=eye(6)+(dydtdom-dydtprevdom)*nac/(nac*dydtprevdom); %saltation matrix when entering wall 13:x=z=0
                        end
                        if strcmp(flag,'exit')
                            S1=eye(6);%saltation matrix when exit wall 4
                        end
                    case 7
                        dydtprevdom=model.lyttle_ODE(TE,YE,prevdom);
                        dydtprevdom=dydtprevdom(1:6);
                        if strcmp(flag,'enter')
                            S1=eye(6)+(dydtdom-dydtprevdom)*nbc/(nbc*dydtprevdom); %saltation matrix when entering wall 23:y=z=0
                        end
                        if strcmp(flag,'exit')
                            S1=eye(6);%saltation matrix when exit wall 4
                        end
                        
                end
            end
            if ~isempty(S1)
                S0=S1;
            end
        end
        
        function multiplySaltation(model,flag,prevdom)
            if isempty(prevdom)
                return;
            end
            
            if model.domain < 4
                if prevdom==0
                    S0=model.saltation(model.t0,model.y0,flag,prevdom); % Calc saltation if entering from interior
                else
                    S0=eye(6); %if dom is not changed
                end
            end
            
            if model.domain == 4
                S0=model.saltation(model.t0,model.y0,flag,prevdom);
            end
            
            if model.domain > 4
                if prevdom~=model.domain
                    S0=model.saltation(model.t0,model.y0,flag,prevdom); % Calc saltation if entering from different domain
                else
                    S0=eye(6); %if dom is not changed
                end
            end
            
            new_y0 = [model.y0(1:8), model.y0(9:14)*S0'];
            model.y0 = new_y0;
            
            if prevdom~=model.domain
                model.t_event = [model.t_event, model.t0];
                model.domain_event = [model.domain_event, model.domain];
                model.Salt{end+1} = S0;
            end
        end
        
        function removeError(model)
            switch model.domain
                case 1
                    model.y0(1)=0;
                case 2
                    model.y0(2)=0;
                case 3
                    model.y0(3)=0;
                case 5
                    model.y0(1)=0;
                    model.y0(2)=0;
                case 6
                    model.y0(1)=0;
                    model.y0(3)=0;
                case 7
                    model.y0(2)=0;
                    model.y0(3)=0;
            end
        end
    end
    
    methods
        function model = set.xinit(model,val)
            model.xinit = val;
            model.yinit = [model.xinit, model.vinit];
        end
        
        function model = set.vinit(model,val)
            model.vinit = val;
            model.yinit = [model.xinit, model.vinit];
        end
    end
    
    methods(Hidden)
        function domain = checkdomain(~, xinit)
            domain = 0;
            x = xinit(1);
            y = xinit(2);
            z = xinit(3);
            if x==0 && y~=0 && z~=0
                domain = 1;
            elseif x~=0 && y==0 && z~=0
                domain = 2;
            elseif x~=0 && y~=0 && z==0
                domain = 3;
            elseif x==0 && y==0 && z~=0
                domain = 5;
            elseif x==0 && y~=0 && z==0
                domain = 6;
            elseif x~=0 && y==0 && z==0
                domain = 7;
            end
        end
    end
    
    
    methods(Hidden)
        % force applied by the muscles
        function f=fmusc(model,u0,u1,x)
            % phi=@(x)-2.598076211353316*x*(x^2-1); % cubic length-tension curve. Constant is 3*sqrt(3)/2
            
            f=model.k0*phi((model.c0-x)/model.w0)*u0+model.k1*phi((model.c1-x)/model.w1)*u1;
        end
        
        % relative linear change in fmusc
        function f = fvar(model,u0,u1,x,du0,du1,dx)
            % phi=@(x)-2.598076211353316*x.*(x.^2-1); % cubic length-tension curve. Constant is 3*sqrt(3)/2
            % phiprime=@(x)-2.598076211353316*(3*x.^2-1);
            
%             j66=-phiprime((model.c0-x)/model.w0).*u0/model.w0+phiprime((model.c1-x)/model.w1).*u1/model.w1;
%             f=phi((model.c0-x)/model.w0).*du0-phi((model.c1-x)/model.w1).*du1 + j66.*dx;
%             
            j66=-model.k0*phiprime((model.c0-x)/model.w0).*u0/model.w0-model.k1*phiprime((model.c1-x)/model.w1).*u1/model.w1;
            f=model.k0*phi((model.c0-x)/model.w0).*du0+model.k1*phi((model.c1-x)/model.w1).*du1 + j66.*dx;

        end
        
        % auxiliary function for Jacobian
        function j=J66(model,u0,u1,x)
            % phiprime=@(x)-2.598076211353316*(3*x^2-1);
%             j=-phiprime((model.c0-x)/model.w0)*u0/model.w0+phiprime((model.c1-x)/model.w1)*u1/model.w1;
            j=-model.k0*phiprime((model.c0-x)/model.w0).*u0/model.w0-model.k1*phiprime((model.c1-x)/model.w1).*u1/model.w1;
        end
    end
end

%% 

function grasper = checkgrasper(xinit)
if xinit(2)+xinit(3)>0.5
    grasper = 1; % closed
else
    grasper = 0;  %open
end
end

function phi = phi(x)
phi=-2.598076211353316*x.*(x.^2-1); % cubic length-tension curve. Constant is 3*sqrt(3)/2
end

function phiprime = phiprime(x) 
phiprime=-2.598076211353316*(3*x.^2-1);
end