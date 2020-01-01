classdef oscillatoryCartPole < rl.env.MATLABEnvironment
    %OSCILLATORYCARTPOLE: Template for defining custom environment in MATLAB.    
    
    %% Properties (set properties' attributes accordingly)
    properties
        % Specify and initialize environment's necessary properties    
        % Acceleration due to gravity in m/s^2
        g = 9.8
        
        % Mass of the cart
        M = 1.0
        
        % Mass of the pendulum
        m = 0.1
        
        % length of the pole
        l = 1
        
        % Max Force the input can apply
        MaxForce = 10
               
        % Sample time
        Ts = 0.01
        
        % Angle at which to fail the episode (radians)
        AngleThreshold = pi/4
        
        % Distance at which to fail the episode
        DisplacementThreshold = 3.5
        
        % plot of cart and pole
        cart_plot = figure('Position', [442.6 345 605.6 138.4])
    end
    
    properties
        % Initialize system state [x,dx,theta,dtheta]'
        State = zeros(4,1)
        
        % keep track of simulation time 
        t = 0
        
        % state time history
        x_time_history = [];
        
        % control time history
        u_time_history = [];
    end
    
    properties(Access = protected)
        % Initialize internal flag to indicate episode termination
        IsDone = false        
    end

    %% Necessary Methods
    methods              
        % Contructor method creates an instance of the environment
        % Change class name and constructor name accordingly
        function this = oscillatoryCartPole()
            % Initialize Observation settings
            ObservationInfo = rlNumericSpec([4 1]);
            ObservationInfo.Name = 'states';
            ObservationInfo.Description = 'x, dx, theta, dtheta';
            
            % Initialize Action settings   
            ActionInfo = rlNumericSpec([1 1]);
            ActionInfo.Name = 'control';
            ActionInfo.LowerLimit = -15;
            ActionInfo.UpperLimit = 15;
            
            % The following line implements built-in functions of RL env
            this = this@rl.env.MATLABEnvironment(ObservationInfo,ActionInfo);
        end
        
        % Apply system dynamics and simulates the environment with the 
        % given action for one step.
        function [Observation,Reward,IsDone,LoggedSignals] = step(this, Action)
            LoggedSignals = [];

            % get control action
            F = Action;
            
            % RK-4 integration of dynamics
%             Observation = RK4(this, F);

            % Euler integration
            Observation = this.State + this.Ts*oscillatoryInvPendulumDynamics(this, this.State, F);
            
            % Update system states
            this.State = Observation;
            
            % add to state time history
            this.x_time_history(end+1,:) = Observation;
            
            % Check terminal condition
            r = Observation(3);
            phi = Observation(1);
            IsDone = abs(r) > this.DisplacementThreshold || abs(phi) > this.AngleThreshold;
            this.IsDone = IsDone;
            
            % Get reward
            Reward = getReward(this, F);
            
            % (optional) use notifyEnvUpdated to signal that the 
            % environment has been updated (e.g. to update visualization)
            notifyEnvUpdated(this);
        end
        
        % Reset environment to initial state and output initial observation
        function InitialObservation = reset(this)
            % Theta (+- 15 deg)
            T0 = 2 * (15*pi/180) * rand - (15*pi/180);  
            % Thetadot
            Td0 = 0;
            % X 
            X0 = 2 * 1 * rand - 1;;
            % Xdot
            Xd0 = 0;
            
            InitialObservation = [T0; Td0; X0; Xd0];
            this.State = InitialObservation;
            
            % initialise simulation time
            this.t = 0;
            
            % initialise time histories
            this.x_time_history = [];
            this.x_time_history(1,:) = InitialObservation';
            
            % (optional) use notifyEnvUpdated to signal that the 
            % environment has been updated (e.g. to update visualization)
            notifyEnvUpdated(this);
        end
    end
    %% Optional Methods (set methods' attributes accordingly)
    methods               
        % Helper methods to create the environment       
        % Reward function
        function Reward = getReward(this, F)
           r = this.State(3);
           phi = this.State(1);
           
           % quadratic cost
           R_qr = -0.1*(5*phi^2 + r^2 + 0.05*F^2);
           
           % extra reward for being close to upright
           R_ur = 0.1*(abs(phi) < 10*pi/180);
           
           % penalty for leaving bounds
           R_p = -100*this.IsDone;
           
           Reward = R_qr + R_ur + R_p;
        end
        
        % (optional) Visualization method
        function plot(this)
            % Initiate the visualization
            this.cart_plot = figure('Position', [442.6 345 605.6 138.4]);
            
            % Update the visualization
            envUpdatedCallback(this)
        end
        
        % (optional) Properties validation through set methods
        function set.State(this,state)
            validateattributes(state,{'numeric'},{'finite','real','vector','numel',4},'','State');
            this.State = double(state(:));
            notifyEnvUpdated(this);
        end
        function set.MaxForce(this,val)
            validateattributes(val,{'numeric'},{'finite','real','positive','scalar'},'','MaxForce');
            this.MaxForce = val;
            updateActionInfo(this);
        end
        function set.Ts(this,val)
            validateattributes(val,{'numeric'},{'finite','real','positive','scalar'},'','Ts');
            this.Ts = val;
        end
        function set.AngleThreshold(this,val)
            validateattributes(val,{'numeric'},{'finite','real','positive','scalar'},'','AngleThreshold');
            this.AngleThreshold = val;
        end
        function set.DisplacementThreshold(this,val)
            validateattributes(val,{'numeric'},{'finite','real','positive','scalar'},'','DisplacementThreshold');
            this.DisplacementThreshold = val;
        end
    end
    
    methods (Access = protected)
        % (optional) update visualization everytime the environment is updated 
        % (notifyEnvUpdated is called)
        function envUpdatedCallback(this)
            % Set the visualization figure as the current figure
            figure(this.cart_plot)
            clf
            
            % get state
            r = this.State(3);
            phi = this.State(1);
            
            % plot cart shape
            cartpoly = polyshape([-0.25 -0.25 0.25 0.25],[-0.125 0.125 0.125 -0.125]);
            cartpoly = translate(cartpoly,[r 0]);
            plot(cartpoly,'FaceColor',[0.8500 0.3250 0.0980])
            hold on
            
            % plot pole
            L = this.l;
            polepoly = polyshape([-0.1 -0.1 0.1 0.1],[0 L L 0]);
            polepoly = translate(polepoly,[r,0]);
            polepoly = rotate(polepoly,rad2deg(phi),[r,0]);
            plot(polepoly,'FaceColor',[0 0.4470 0.7410])
            
            % cart plot limits
            xlim([-1.25*this.DisplacementThreshold 1.25*this.DisplacementThreshold]);
            ylim([0 1.35*this.l]);
            
            % plot angle thresholds
            phi_max = pi/2 - this.AngleThreshold;
            max_phi_line_x = linspace(r, r + L, 10);
            max_phi_line_y = tan(phi_max)*(max_phi_line_x - r);
            if phi < -this.AngleThreshold
                plot(max_phi_line_x, max_phi_line_y, 'r--')
            else
                plot(max_phi_line_x, max_phi_line_y, 'g--')
            end
            phi_max = pi/2 + this.AngleThreshold;
            max_phi_line_x = linspace(r, r - L, 10);
            max_phi_line_y = tan(phi_max)*(max_phi_line_x - r);
            if phi > this.AngleThreshold
                plot(max_phi_line_x, max_phi_line_y, 'r--')
            else
                plot(max_phi_line_x, max_phi_line_y, 'g--')
            end
            
            % plot displacement thresholds
            r_max = this.DisplacementThreshold;
            max_r_x = r_max*ones(1, 15);
            max_r_y = linspace(0, 1.25*L, 15);
            if r > r_max
                plot(max_r_x, max_r_y, 'r--')
            else
                plot(max_r_x, max_r_y, 'g--')
            end
            r_max = this.DisplacementThreshold;
            max_r_x = -r_max*ones(1, 15);
            max_r_y = linspace(0, 1.25*L, 15);
            if r < -r_max
                plot(max_r_x, max_r_y, 'r--')
            else
                plot(max_r_x, max_r_y, 'g--')
            end

            hold off
%             plot(linspace(0, this.t, this.t/this.Ts + 1), this.x_time_history)
%             labels = {'$r$', '$\dot{r}$', '$\phi$', '$\dot{\phi}$'};
%             legend(labels, 'Interpreter', 'latex');          
%             drawnow();
        end
    end
end

function dx = oscillatoryInvPendulumDynamics(this, x, F)
    % Unpack state vector
    rdot = x(4);
    phi = x(1);
    phidot = x(2);
    
    % Cache to avoid recomputation
    cphi = cos(phi); sphi = sin(phi);
    s2phi = sin(2*phi); c2phi = cos(2*phi);
    
    rddot = (-this.m*this.g*s2phi + 2*this.l*this.m*sphi*phidot^2)/(this.m*c2phi - this.m - 2*this.M) - (2*F)/(this.m*c2phi - this.m - 2*this.M);
    phiddot = 2*(-this.g*(this.m + this.M)*sphi + this.l*this.m*cphi*sphi*phidot^2)/(this.l*(this.m*c2phi - this.m - 2*this.M)) - (2*F*cphi)/(this.l*(this.m*c2phi - this.m - 2*this.M));
    
    dx = [rdot; rddot; phidot; phiddot];
end

function xnew = RK4(this, F)
    h = this.Ts;
    x = this.State;
    
    k1 = h*oscillatoryInvPendulumDynamics(this, x, F);
    k2 = h*oscillatoryInvPendulumDynamics(this, x + 0.5*k1, F);
    k3 = h*oscillatoryInvPendulumDynamics(this, x + 0.5*k2, F);
    k4 = h*oscillatoryInvPendulumDynamics(this, x + k3, F);
    
    xnew = x + (k1 + 2*k2 + 2*k3 + k4)/6;
    this.t = this.t + h;
end
