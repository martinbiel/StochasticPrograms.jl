var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "#StochasticPrograms.jl-1",
    "page": "Home",
    "title": "StochasticPrograms.jl",
    "category": "section",
    "text": "A modeling framework for stochastic programming problems"
},

{
    "location": "#Summary-1",
    "page": "Home",
    "title": "Summary",
    "category": "section",
    "text": "StochasticPrograms models recourse problems where an initial decision is taken, unknown parameters are observed, followed by recourse decisions to correct any inaccuracy in the initial decision. The underlying optimization problems are formulated in JuMP.jl. In StochasticPrograms, model instantiation can be deferred until required. As a result, scenario data can be loaded/reloaded to create/rebuild the recourse model at a later stage, possibly on separate machines in a cluster. Another consequence of deferred model instantiation is that StochasticPrograms.jl can provide stochastic programming constructs, such as expected value of perfect information (EVPI) and value of the stochastic solution (VSS), to gain deeper insights about formulated recourse problems. A good introduction to recourse models, and to the stochastic programming constructs provided in this package, is given in Introduction to Stochastic Programming. A stochastic program has a structure that can be exploited in solver algorithms. Therefore, StochasticPrograms provides a structured solver interface, implemented by LShapedSolvers.jl and ProgressiveHedgingSolvers.jl. StochasticPrograms has parallel capabilities, implemented using the standard Julia library for distributed computing."
},

{
    "location": "#Features-1",
    "page": "Home",
    "title": "Features",
    "category": "section",
    "text": "Flexible problem definition\nDeferred model instantiation\nScenario data injection\nNatively distributed\nInterface to structure-exploiting solver algorithms\nEfficient parallel implementations of classical algorithmsConsider Quick start for a tutorial explaining how to get started using StochasticPrograms.Some examples of models written in StochasticPrograms can be found on the Examples page.See the Index for the complete list of documented functions and types."
},

{
    "location": "#Manual-Outline-1",
    "page": "Home",
    "title": "Manual Outline",
    "category": "section",
    "text": "Pages = [\"manual/quickstart.md\", \"manual/data.md\", \"manual/modeldef.md\", \"manual/distributed.md\", \"manual/structuredsolvers.md\", \"manual/examples.md\"]"
},

{
    "location": "#Library-Outline-1",
    "page": "Home",
    "title": "Library Outline",
    "category": "section",
    "text": "Pages = [\"library/public.md\", \"library/solverinterface.md\"]"
},

{
    "location": "#main-index-1",
    "page": "Home",
    "title": "Index",
    "category": "section",
    "text": "Pages = [\"library/public.md\"]\nOrder   = [:type, :macro, :function]"
},

{
    "location": "manual/quickstart/#",
    "page": "Quick start",
    "title": "Quick start",
    "category": "page",
    "text": ""
},

{
    "location": "manual/quickstart/#Quick-start-1",
    "page": "Quick start",
    "title": "Quick start",
    "category": "section",
    "text": ""
},

{
    "location": "manual/quickstart/#Installation-1",
    "page": "Quick start",
    "title": "Installation",
    "category": "section",
    "text": "StochasticPrograms is installed as follows:pkg> add StochasticProgramsAfterwards, the functionality can be made available in a module or REPL through:using StochasticPrograms"
},

{
    "location": "manual/quickstart/#Stochastic-programs-1",
    "page": "Quick start",
    "title": "Stochastic programs",
    "category": "section",
    "text": "A two-stage linear stochastic program has the following mathematical representation:DeclareMathOperator*minimizeminimize\nbeginaligned\n minimize_x in mathbbR^n  quad c^T x + operatornamemathbbE_omega leftQ(xxi(omega))right \n textst  quad Ax = b \n  quad x geq 0\nendalignedwherebeginaligned\n    Q(xxi(omega)) = min_y in mathbbR^m  quad q_omega^T y \n    textst  quad T_omegax + Wy = h_omega \n     quad y geq 0\n  endalignedIf the sample space Omega is finite, stochastic program has a closed form that can be represented on a computer. Such functionality is provided by StochasticPrograms. If the sample space Omega is infinite, sampling techniques can be used to represent the stochastic program using finite SAA instances."
},

{
    "location": "manual/quickstart/#A-simple-stochastic-program-1",
    "page": "Quick start",
    "title": "A simple stochastic program",
    "category": "section",
    "text": "To showcase the use of StochasticPrograms we will walk through a simple example. Consider the following stochastic program: (taken from Introduction to Stochastic Programming).DeclareMathOperator*minimizeminimize\nbeginaligned\n minimize_x_1 x_2 in mathbbR  quad 100x_1 + 150x_2 + operatornamemathbbE_omega leftQ(x_1x_2xi(omega))right \n textst  quad x_1+x_2 leq 120 \n  quad x_1 geq 40 \n  quad x_2 geq 20\nendalignedwherebeginaligned\n Q(x_1x_2xi(omega)) = min_y_1y_2 in mathbbR  quad q_1(omega)y_1 + q_2(omega)y_2 \n textst  quad 6y_1+10y_2 leq 60x_1 \n  quad 8y_1 + 5y_2 leq 80x_2 \n  quad 0 leq y_1 leq d_1(omega) \n  quad 0 leq y_2 leq d_2(omega)\nendalignedand the stochastic variable  xi(omega) = beginpmatrix\n     q_1(omega)  q_2(omega)  d_1(omega)  d_2(omega)\n  endpmatrix^Ttakes on the value  xi_1 = beginpmatrix\n    -24  -28  500  100\n  endpmatrix^Twith probability 04 and  xi_1 = beginpmatrix\n    -28  -32  300  300\n  endpmatrix^Twith probability 06. In the following, we consider how to model, analyze, and solve this stochastic program using StochasticPrograms."
},

{
    "location": "manual/quickstart/#Scenario-definition-1",
    "page": "Quick start",
    "title": "Scenario definition",
    "category": "section",
    "text": "First, we introduce a scenario type that can encompass the scenarios xi_1 and xi_2 above. This can be achieved conviently through the @scenario macro:@scenario Simple = begin\n    q₁::Float64\n    q₂::Float64\n    d₁::Float64\n    d₂::Float64\nendNow, xi_1 and xi_2 can be created through:ξ₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)andξ₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)Some useful functionality is automatically made available when introducing scenarios in this way. For example, we can check the discrete probability of a given scenario occuring:probability(ξ₁)Moreover, we can form the expected scenario out of a given set:ξ̄ = expected([ξ₁, ξ₂])"
},

{
    "location": "manual/quickstart/#Stochastic-program-definition-1",
    "page": "Quick start",
    "title": "Stochastic program definition",
    "category": "section",
    "text": "We are now ready to create a stochastic program based on the introduced scenario type. Optionally, we can also supply a capable MathProgBase solver that can be used internally when necessary. Consider:using GLPKMathProgInterface\n\nsp = StochasticProgram([ξ₁, ξ₂], solver = GLPKSolverLP())The above command creates a stochastic program and preloads the two defined scenarios. The provided solver will be used internally when necessary. For clarity, we will still explicitly supply a solver when it is required. Now, we provide model recipes for the first and second stage of the example problem. The first stage is straightforward, and is defined using JuMP syntax inside a @first_stage block:@first_stage sp = begin\n    @variable(model, x₁ >= 40)\n    @variable(model, x₂ >= 20)\n    @objective(model, Min, 100*x₁ + 150*x₂)\n    @constraint(model, x₁ + x₂ <= 120)\nendThe recipe was immediately used to generate an instance of the first-stage model. Next, we give a second stage recipe inside a @second_stage block:@second_stage sp = begin\n    @decision x₁ x₂\n    ξ = scenario\n    @variable(model, 0 <= y₁ <= ξ.d₁)\n    @variable(model, 0 <= y₂ <= ξ.d₂)\n    @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)\n    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)\n    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)\nendEvery first-stage variable that occurs in the second stage model is annotated with @decision at the beginning of the definition. Moreover, the scenario data is referenced through scenario. Instances of the defined scenario SimpleScenario will be injected to create instances of the second stage model. The second stage recipe is immediately used to generate second stage models for each preloaded scenario. Hence, the stochastic program definition is complete. We can now print the program and confirm that it indeed models the example recourse problem given above:print(sp)"
},

{
    "location": "manual/quickstart/#Deterministically-equivalent-problem-1",
    "page": "Quick start",
    "title": "Deterministically equivalent problem",
    "category": "section",
    "text": "Since the example problem is small it is straightforward to work out the extended form:beginaligned\n minimize_x_1 x_2 y_11 y_21 y_12 y_22 in mathbbR  quad 100x_1 + 150x_2 - 96y_11 - 112y_21 - 168y_12 - 192y_22  \n textst  quad x_1 + x_2 leq 120 \n  quad 6 y_11 + 10 y_21 leq 60 x_1 \n  quad 8 y_11 + 5 y_21 leq 80 x_2 \n  quad 6 y_12 + 10 y_22 leq 60 x_1 \n  quad 8 y_12 + 5 y_22 leq 80 x_2 \n  quad x_1 geq 40 \n  quad x_2 geq 20 \n  quad 0 leq y_11 leq 500 \n  quad 0 leq y_21 leq 100 \n  quad 0 leq y_12 leq 300 \n  quad 0 leq y_22 leq 300\nendalignedwhich is also commonly referred to as the deterministically equivalent problem. This construct is available in StochasticPrograms through:dep = DEP(sp)\nprint(dep)"
},

{
    "location": "manual/quickstart/#Evaluate-decisions-1",
    "page": "Quick start",
    "title": "Evaluate decisions",
    "category": "section",
    "text": "With the stochastic program defined, we can evaluate the performance of different first-stage decisions. The expected value of a given first-stage decision x is given byV(x) = c^T x + operatornamemathbbE_omega leftQ(xxi(omega))rightIf the sample space is finite, the above expressions has a closed form that is readily calculated. Consider the following first-stage decision:x = [40., 20.]The expected result of taking this decision in the simple model can be determined through:evaluate_decision(sp, x, solver = GLPKSolverLP())The supplied solver is used to solve all available second stage models, with fixed first-stage values. These outcome models can be built manually by supplying a scenario and the first-stage decision.print(outcome_model(sp, ξ₁, x))Moreover, we can evaluate the result of the decision in a given scenario, i.e. solving a single outcome model, through:evaluate_decision(sp, ξ₁, x, solver = GLPKSolverLP())In the sample space is infinite, or if the underlying random variable xi is continuous, a first-stage decision can only be evaluated in a stochastic sense. For further reference, consider evaluate_decision, lower_bound and confidence_interval."
},

{
    "location": "manual/quickstart/#Optimal-first-stage-decision-1",
    "page": "Quick start",
    "title": "Optimal first-stage decision",
    "category": "section",
    "text": "The optimal first-stage decision is the decision that gives the best expected result over all available scenarios. This decision can be determined by solving the deterministically equivalent problem, by supplying a capable solver. Structure exploiting solvers are outlined in Structured solvers. In addition, it is possible to give a MathProgBase solver capable of solving linear programs. For example, we can solve sp with the GLPK solver as follows:optimize!(sp, solver = GLPKSolverLP())Internally, this generates and solves the extended form of sp. We can now inspect the optimal first-stage decision through:x_opt = optimal_decision(sp)Moreover, the optimal value, i.e. the expected outcome of using the optimal decision, is acquired through:optimal_value(sp)which of course coincides with the result of evaluating the optimal decision:evaluate_decision(sp, x_opt, solver = GLPKSolverLP())This value is commonly referred to as the value of the recourse problem (VRP). We can also calculate it directly through:VRP(sp, solver = GLPKSolverLP())"
},

{
    "location": "manual/quickstart/#Wait-and-see-models-1",
    "page": "Quick start",
    "title": "Wait-and-see models",
    "category": "section",
    "text": "If we assume that we know what the actual outcome will be, we would be interested in the optimal course of action in that scenario. This is the concept of wait-and-see models. For example if ξ₁ is believed to be the actual outcome, we can define a wait-and-see model as follows:ws = WS(sp, ξ₁)\nprint(ws)The optimal first-stage decision in this scenario can be determined through:x₁ = WS_decision(sp, ξ₁, solver = GLPKSolverLP())We can evaluate this decision:evaluate_decision(sp, x₁, solver = GLPKSolverLP())The outcome is of course worse than taking the optimal decision. However, it would perform better if ξ₁ is the actual outcome:evaluate_decision(sp, ξ₁, x₁, solver = GLPKSolverLP())as compared to:evaluate_decision(sp, ξ₁, x_opt, solver = GLPKSolverLP())Another important concept is the wait-and-see model corresponding to the expected future scenario. This is referred to as the expected value problem and can be generated through:evp = EVP(sp)\nprint(evp)Internally, this generates the expected scenario out of the available scenarios and forms the respective wait-and-see model. The optimal first-stage decision associated with the expected value problem is conviently determined usingx̄ = EVP_decision(sp, solver = GLPKSolverLP())Again, we can evaluate this decision:evaluate_decision(sp, x̄, solver = GLPKSolverLP())This value is often referred to as the expected result of using the expected value solution (EEV), and is also available through:EEV(sp, solver = GLPKSolverLP())"
},

{
    "location": "manual/quickstart/#Stochastic-performance-1",
    "page": "Quick start",
    "title": "Stochastic performance",
    "category": "section",
    "text": "Finally, we consider some performance measures of the defined model. The expected value of perfect information is the difference between the value of the recourse problem and the expected result of having perfect knowledge. In other words, it involes solving the recourse problem as well as every wait-and-see model that can be formed from the available scenarios. We calculate it as follows:EVPI(sp, solver = GLPKSolverLP())The resulting value indicates the expected gain of having perfect information about future scenarios. Another concept is the value of the stochastic solution, which is the difference between the value of the recourse problem and the EEV. We calculate it as follows:VSS(sp, solver = GLPKSolverLP())The resulting value indicates the gain of including uncertainty in the model formulation."
},

{
    "location": "manual/data/#",
    "page": "Stochastic data",
    "title": "Stochastic data",
    "category": "page",
    "text": ""
},

{
    "location": "manual/data/#Stochastic-data-1",
    "page": "Stochastic data",
    "title": "Stochastic data",
    "category": "section",
    "text": "Decoupling data design and model design is a fundamental principle in StochasticPrograms. This decoupling is achieved through data injection. By data we mean parameters in an optimization problem. In StochasticPrograms, this data is either deterministic and related to a specific stage, or uncertain and related to a specific scenario."
},

{
    "location": "manual/data/#Stage-data-1",
    "page": "Stochastic data",
    "title": "Stage data",
    "category": "section",
    "text": "Stage data is related to parameters that always appear in the first or second stage of a stochastic program. These parameters are deterministic and are the same across all scenarios. Stage data must be supplied when creating a stochastic program, through specialized constructors. However, the data can later be mutated without having to construct a new stochastic program instance. Any stage related data can then be accessed through the reserved keyword stage in @first_stage and @second_stage blocks. To showcase, we consider a minimal stochastic program:DeclareMathOperator*maximizemaximize\nbeginaligned\n maximize_x in mathbbR  quad x + operatornamemathbbE_omega leftQ(x xi(omega))right \n textst  quad l_1 leq x leq u_1\nendalignedwherebeginaligned\n Q(x xi(omega)) = max_y in mathbbR  quad q_omega y \n textst  quad y + x leq U \n  quad l_2 leq y leq u_2\nendalignedand the stochastic variable  xi(omega) = q_omegatakes on the value 1 or -1 with equal probability. Here, the first stage contains the two parameters: l_1 and u_1. The second stage contains the three scenario-independent parameters: U, l_2, and u_2. The following defines this problem in StochasticPrograms, with some chosen parameter values:using StochasticPrograms\nusing GLPKMathProgInterface\n\n@scenario Simple = begin\n    q::Float64\nend\n\nξ₁ = SimpleScenario(1., probability = 0.5)\nξ₂ = SimpleScenario(-1., probability = 0.5)\n\nl₁ = -1.\nu₁ = 1.\n\nU = 2.\nl₂ = -1.\nu₂ = 1.\n\nsp = StochasticProgram((l₁,u₁), (U,l₂,u₂), [ξ₁,ξ₂])\n\n@first_stage sp = begin\n    l₁, u₁ = stage\n    @variable(model, l₁ <= x <= u₁)\n    @objective(model, Max, x)\nend\n\n@second_stage sp = begin\n    @decision x\n    U, l₂, u₂ = stage\n    ξ = scenario\n    @variable(model, l₂ <= y <= u₂)\n    @objective(model, Max, ξ.q*y)\n    @constraint(model, y + x <= U)\nend\n\nprint(sp)\n\nprint(\"VRP = $(VRP(sp, solver = GLPKSolverLP()))\")Now, we can investigate the impact of the stage parameters by changing them slightly and regenerate the problem:l₁ = -2.\nu₁ = 2.\n\nU = 2.\nl₂ = -0.5\nu₂ = 0.5\n\nset_first_stage_data!(sp, (l₁,u₁))\nset_second_stage_data!(sp, (U,l₂,u₂))\n\ngenerate!(sp) # Regenerate problem\n\nprint(sp)\n\nprint(\"VRP = $(VRP(sp, solver = GLPKSolverLP()))\")"
},

{
    "location": "manual/data/#Scenario-data-1",
    "page": "Stochastic data",
    "title": "Scenario data",
    "category": "section",
    "text": "Any uncertain parameter in the second stage of a stochastic program should be included in some predefined AbstractScenario type. Hence, all uncertain parameters in a stochastic program must be identified before defining the models. In brief, StochasticPrograms demands two functions from this abstraction. The discrete probability of a given AbstractScenario occurring should be returned from probability. Also, the expected scenario out of a collection of given AbstractScenarios should be returned by expected. StochasticPrograms provides a convenience macro, @scenario, for creating scenario types that adhere to this abstraction. If the identified uncertain parameters is a collection of numerical values, this is the recommended way to define the required scenario type.using StochasticPrograms\n\n@scenario Example = begin\n    X::Float64\nend\n\ns₁ = ExampleScenario(1., probability = 0.5)\ns₂ = ExampleScenario(5., probability = 0.5)\n\nprintln(\"Probability of s₁: $(probability(s₁))\")\n\ns = expected([s₁, s₂])\n\nprintln(\"Expectation over s₁ and s₂: $s\")\nprintln(\"Expectated X: $(s.scenario.X)\")\nHere, all the required operations are correctly defined.There are some caveats to note. First, the autogenerated requires an additive zero element of the introduced scenario type. For simple numeric types this is autogenerated as well. However, say that we want to extend the above scenario with some vector parameter of size 2:using StochasticPrograms\n\n@scenario Example = begin\n    X::Float64\n    Y::Vector{Float64}\nendIn this case, we must provide an implementation of zero using @zero:using StochasticPrograms\n\n@scenario Example = begin\n    X::Float64\n    Y::Vector{Float64}\n\n    @zero begin\n        return Example(0.0, [0.0, 0.0])\n    end\nend\n\ns₁ = ExampleScenario(1., ones(2), probability = 0.5)\ns₂ = ExampleScenario(5., -ones(2), probability = 0.5)\n\nprintln(\"Probability of s₁: $(probability(s₁))\")\n\ns = expected([s₁, s₂])\n\nprintln(\"Expectation over s₁ and s₂: $s\")\nprintln(\"Expectated X: $(s.scenario.X)\")\nprintln(\"Expectated Y: $(s.scenario.Y)\")Another caveat is that the expected function can only be auto generated for fields that support addition and scalar multiplication with Float64. Consider:using StochasticPrograms\n\n@scenario Example = begin\n    X::Float64\n    Y::Vector{Float64}\n    Z::Int\n\n    @zero begin\n        return Example(0.0, [0.0, 0.0], 0)\n    end\nendAgain, the solution is to provide an implementation of expected, this time using @expectation:using StochasticPrograms\n\n@scenario Example = begin\n    X::Float64\n    Y::Vector{Float64}\n    Z::Int\n\n    @zero begin\n        return Example(0.0, [0.0, 0.0], 0)\n    end\n\n    @expectation begin\n        X = sum([probability(s)*s.X for s in scenarios])\n        Y = sum([probability(s)*s.Y for s in scenarios])\n        Z = sum([round(Int, probability(s)*s.Z) for s in scenarios])\n        return Example(X, Y, Z)\n    end\nend\n\ns₁ = ExampleScenario(1., ones(2), 1, probability = 0.5)\ns₂ = ExampleScenario(5., -ones(2), -1, probability = 0.5)\n\nprintln(\"Probability of s₁: $(probability(s₁))\")\n\ns = expected([s₁, s₂])\n\nprintln(\"Expectation over s₁ and s₂: $s\")\nprintln(\"Expectated X: $(s.scenario.X)\")\nprintln(\"Expectated Y: $(s.scenario.Y)\")\nprintln(\"Expectated Z: $(s.scenario.Z)\")For most problems, @scenario will probably be adequate. Otherwise consider defining Custom scenarios."
},

{
    "location": "manual/data/#Sampling-1",
    "page": "Stochastic data",
    "title": "Sampling",
    "category": "section",
    "text": "using Random\nRandom.seed!(1)Typically, we do not have exact knowledge of all possible future scenarios. However, we often have access to some model of the uncertainty. For example, scenarios could originate from:A stochastic variable with known distribution\nA time series fitted to data\nA nerual network predictionEven if the exact scenario distribution is unknown, or not all possible scenarios are available, we can still formulate a stochastic program that approximates the model we wish to formulate. This is achieved through a technique called sampled average approximation, which is based on sampling. The idea is to sample a large number n of scenarios with equal probability frac1n and then use them to generate and solve a stochastic program. By the law of large numbers, the result will converge with probability 1 to the \"true\" solution with increasing n.StochasticPrograms accepts AbstractSampler objects in place of AbstractScenario. However, an AbstractSampler is always linked to some underlying AbstractScenario type, which is reflected in the resulting stochastic program as well. Samplers are conviniently created using @sampler. We can define a simple scenario type and a simple sampler as follows:using StochasticPrograms\n\n@scenario Example = begin\n    ξ::Float64\nend\n\n@sampler Example = begin\n    w::Float64\n\n    Example(w::AbstractFloat) = new(w)\n\n    @sample begin\n        w = sampler.w\n        return ExampleScenario(w*randn(), probability = rand())\n    end\nendThis creates a new AbstractSampler type called ExampleSampler, which samples ExampleScenarios. Now, we can create a sampler object and sample a scenariosampler = ExampleSampler(2.)\n\ns = sampler()\n\nprintln(s)\nprintln(\"ξ: $(s.ξ)\")It is possible to create other sampler objects for the ExampleScenario, by providing a new unique name:@sampler Another Example = begin\n    w::Float64\n    d::Float64\n\n    Another(w::AbstractFloat, d::AbstractFloat) = new(w, d)\n\n    @sample begin\n        w = sampler.w\n        d = sampler.d\n        return ExampleScenario(w*randn() + d, probability = rand())\n    end\nend\n\nanother = AnotherSampler(2., 6.)\n\ns = another()\n\nprintln(s)\nprintln(\"ξ: $(s.ξ)\")Now, lets create a stochastic program based on the ExampleScenario type:sp = StochasticProgram(ExampleScenario)\n\n@first_stage sp = begin\n    @variable(model, x >= 0)\n    @objective(model, Min, x)\nend\n\n@second_stage sp = begin\n    @decision x\n    ξ = scenario.ξ\n    @variable(model, y)\n    @objective(model, Min, y)\n    @constraint(model, y + x == ξ)\nendNow, we can sample 5 scenarios using the first sampler to generate 5 subproblems:sample!(sp, sampler, 5)Printing yields:print(sp)Sampled stochastic programs are solved as usual:using GLPKMathProgInterface\n\noptimize!(sp, solver = GLPKSolverLP())\n\nprintln(\"optimal decision: $(optimal_decision(sp))\")\nprintln(\"optimal value: $(optimal_value(sp))\")Again, if the functionality offered by @sampler is not adequate, consider Custom scenarios."
},

{
    "location": "manual/data/#SAA-1",
    "page": "Stochastic data",
    "title": "SAA",
    "category": "section",
    "text": "The command SAA is used to create sampled average approximations of a given stochastic program by supplying a sampler object.saa = SAA(sp, sampler, 10)"
},

{
    "location": "manual/data/#Custom-scenarios-1",
    "page": "Stochastic data",
    "title": "Custom scenarios",
    "category": "section",
    "text": "using Random\nRandom.seed!(1)More complex scenario designs are probably not implementable using @scenario. However, it is still possible to create a custom scenario type as long as:The type is a subtype of AbstractScenario\nThe type implements probability\nThe type implements expected, which should return an additive zero element if given an empty arrayThe restriction on expected is there to support taking expectations in a distributed environment. We are also free to define custom sampler objects, as long as:The sampler type is a subtype of AbstractSampler\nThe sampler type implements a functor call that performs the samplingSee the Continuous scenario distribution for an example of custom scenario/sampler implementations."
},

{
    "location": "manual/modeldef/#",
    "page": "Stochastic models",
    "title": "Stochastic models",
    "category": "page",
    "text": ""
},

{
    "location": "manual/modeldef/#Stochastic-models-1",
    "page": "Stochastic models",
    "title": "Stochastic models",
    "category": "section",
    "text": "Now, tools related to model definitions in StochasticPrograms are introduced in more detail."
},

{
    "location": "manual/modeldef/#Model-objects-1",
    "page": "Stochastic models",
    "title": "Model objects",
    "category": "section",
    "text": "To further seperate model design from data design, StochasticPrograms provides a stochastic model object. This object can be used to store the optimization models before introducing scenario data. Consider the following alternative approach to the simple problem introduced in the Quick start:using StochasticPrograms\n\nsimple_model = StochasticModel((sp) -> begin\n	@first_stage sp = begin\n		@variable(model, x₁ >= 40)\n		@variable(model, x₂ >= 20)\n		@objective(model, Min, 100*x₁ + 150*x₂)\n		@constraint(model, x₁ + x₂ <= 120)\n	end\n	@second_stage sp = begin\n		@decision x₁ x₂\n		ξ = scenario\n		@variable(model, 0 <= y₁ <= ξ.d₁)\n		@variable(model, 0 <= y₂ <= ξ.d₂)\n		@objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)\n		@constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)\n		@constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)\n	end\nend)The resulting model object can be used to instantiate different stochastic programs as long as the corresponding scenario data conforms to the second stage model. For example, lets introduce a similar scenario type and use it to construct the same stochastic program as in the Quick start:@scenario AnotherSimple = begin\n    q₁::Float64\n    q₂::Float64\n    d₁::Float64\n    d₂::Float64\nend\n\nξ₁ = AnotherSimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)\nξ₂ = AnotherSimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)\n\nsp = instantiate(simple_model, [ξ₁, ξ₂])Moreoever, SAA models are constructed in a straightforward way. Consider the following:@sampler AnotherSimple = begin\n    @sample begin\n        return AnotherSimpleScenario(-24.0 + 2*(2*rand()-1),\n									 -28.0 + (2*rand()-1),\n									 300.0 + 100*(2*rand()-1),\n									 300.0 + 100*(2*rand()-1),\n									 probability = rand())\n    end\nend\n\nsaa = SAA(simple_model, AnotherSimpleSampler(), 10)This allows the user to clearly distinguish between the often abstract base-model:DeclareMathOperator*minimizeminimize\nbeginaligned\n minimize_x in mathbbR^n  quad c^T x + operatornamemathbbE_omega leftQ(xxi(omega))right \n textst  quad Ax = b \n  quad x geq 0\nendalignedand look-ahead models that approximate the base-model:DeclareMathOperator*minimizeminimize\nbeginaligned\n minimize_x in mathbbR^n y_s in mathbbR^m  quad c^T x + sum_s = 1^n pi_s q_s^Ty_s \n textst  quad Ax = b \n  quad T_s x + W y_s = h_s quad s = 1 dots n \n  quad x geq 0 y_s geq 0 quad s = 1 dots n\nendaligned"
},

{
    "location": "manual/modeldef/#Deferred-models-1",
    "page": "Stochastic models",
    "title": "Deferred models",
    "category": "section",
    "text": "Another tool StochasticPrograms is deferred model instantiation. Consider again the simple problem introduced in the Quick start, but with some slight differences:using StochasticPrograms\n\n@scenario Simple = begin\n    q₁::Float64\n    q₂::Float64\n    d₁::Float64\n    d₂::Float64\nend\n\nsp = StochasticProgram(SimpleScenario)\n\n@first_stage sp = begin\n    @variable(model, x₁ >= 40)\n    @variable(model, x₂ >= 20)\n    @objective(model, Min, 100*x₁ + 150*x₂)\n    @constraint(model, x₁ + x₂ <= 120)\nend defer\n\n@second_stage sp = begin\n    @decision x₁ x₂\n    ξ = scenario\n    @variable(model, 0 <= y₁ <= ξ.d₁)\n    @variable(model, 0 <= y₂ <= ξ.d₂)\n    @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)\n    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)\n    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)\nendThere are two things to note here. First, no scenarios have been loaded yet, so no second stage models were instansiated. Moreover, the first stage was defined with the defer keyword, and the printout states that the first stage is deferred. This means that the first stage model has not yet been instansiated, but the stochastic program instance has a model recipe that can be used to generate it when required:println(has_generator(sp, :stage_1))\nprintln(has_generator(sp, :stage_2))Now, we add the simple scenarios to the stochastic program instance, also with a defer keyword:ξ₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)\nξ₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)\nadd_scenarios!(sp, [ξ₁, ξ₂], defer = true)The two scenarios are loaded, but no second stage models were instansiated. Deferred stochastic programs will always be generated in full when required. For instance, this occurs when calling optimize!. Furthermore, we can explicitly instansiate the stochastic program using generate!:generate!(sp)"
},

{
    "location": "manual/distributed/#",
    "page": "Distributed stochastic programs",
    "title": "Distributed stochastic programs",
    "category": "page",
    "text": ""
},

{
    "location": "manual/distributed/#Distributed-stochastic-programs-1",
    "page": "Distributed stochastic programs",
    "title": "Distributed stochastic programs",
    "category": "section",
    "text": "Stochastic programs related to industrial applications are often associated with complex models and vast numbers of scenarios, often in the order of 1000-1000000. Hence, the extensive form can have billions of variables and constraints, and often does not fit in memory on a single machine. This clarifies the need for solution approaches that work in parallel on distributed data when instansiating and optimizing large-scale stochastic programs.If multiple Julia processes are available, locally or in a cluster, StochasticPrograms natively distributes any defined stochastic programs on the available processing nodes. As an example, we revisit the simple problem introduced in the Quick start:using Distributed\n\naddprocs(3)\n\nusing StochasticPrograms\n\n@scenario Simple = begin\n    q₁::Float64\n    q₂::Float64\n    d₁::Float64\n    d₂::Float64\nend@scenario automatically ensures that the introduced scenario type is available on all processes. Define the stochastic program in the usual way:sp = StochasticProgram(SimpleScenario)\n@first_stage sp = begin\n    @variable(model, x₁ >= 40)\n    @variable(model, x₂ >= 20)\n    @objective(model, Min, 100*x₁ + 150*x₂)\n    @constraint(model, x₁ + x₂ <= 120)\nend\n@second_stage sp = begin\n    @decision x₁ x₂\n    ξ = scenario\n    @variable(model, 0 <= y₁ <= ξ.d₁)\n    @variable(model, 0 <= y₂ <= ξ.d₂)\n    @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)\n    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)\n    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)\nendDistributed stochastic program with:\n * 0 scenarios of type SimpleScenario\n * 2 decision variables\n * 0 recourse variables\nSolver is default solverThe printout indicates that the created stochastic program is distributed. Technically, nothing has been distributed yet since there are no scenarios. The first stage problem always reside on the master node. Let us now add the two scenarios. We could add the in the usual way with add_scenario!. However, this would create the scenario data on the master node and then send the data. This is fine for this small scenario, but for a large-scale program this would involve a lot of data passing. As stated @scenario made the scenario type available on all nodes, so a better approach is to:add_scenario!(sp; defer = true, w = 2) do\n    return SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)\nend\nadd_scenario!(sp; defer = true, w = 3) do\n    return SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)\nendDistributed stochastic program with:\n * 2 scenarios of type SimpleScenario\n * 2 decision variables\n * deferred second stage\nSolver is default solverThis instansiates the scenarios locally on each node and loads them into local storage. An even more effective paradigm is to only send a lightweight AbstractSampler object to each node, and have them sample any required scenario. This is the recommended approach for large-scale stochastic programs. The model generation was purposefully deferred to make a final point. If we now call:generate!(sp)Distributed stochastic program with:\n * 2 scenarios of type SimpleScenario\n * 2 decision variables\n * 2 recourse variables\nSolver is default solverthe lightweight model recipes are passed to all worker nodes. The worker nodes then use the recipes to instansiate second stage models in parallel. This is one of the intended outcomes of the design choices made in StochasticPrograms. The separation between data design and model design allows us to minimize data passing in a natural way.Many operations in StochasticPrograms are embarassingly parallel which is exploited throughout when a stochastic program is distributed. Notably:evaluate_decision\nEVPI\nVSSPerform many subproblem independent operations in parallel. The best performance is achieved if the optimization of the recourse problem is performed by an algorithm that can operate in parallel on the distributed stochastic programs. The solver suites LShapedSolvers.jl and ProgressiveHedgingSolvers.jl are examples of this. For example, we can optimize the distributed version of the simple stochastic program with a parallelized L-shaped algorithm as follows:using LShapedSolvers\nusing GLPKMathProgInterface\n\noptimize!(sp, solver = LShapedSolver(GLPKSolverLP(), distributed = true))Distributed L-Shaped Gap  Time: 0:00:03 (6 iterations)\n  Objective:       -855.8333333333339\n  Gap:             0.0\n  Number of cuts:  7\n:OptimalA quick note should also be made about the API calls that become less efficient in a distributed setting. This includes all calls that collect data that reside on remote processes. The functions in this category that involve the most data passing is scenarios, which fetches all scenarios in the stochastic program, and subproblems, which fetches all second stage models in the stochastic program. If these collections are required frequently it is recommended to not distribute the stochastic program. This can be ensured by supplying procs = [1] to the constructor call. Individual queries scenario(stochasticprogram, i) and subproblem(stochasticprogram, i) are viable depending on the size of the scenarios/models. If a MathProgBase solver is supplied to a distributed stochastic program it will fetch all scenarios to the master node and attempt to build the extensive form. Long computation times are expected for large-scale models, assuming they fit in memory. If so, it is again recommended to avoid distributing the stochastic program through procs = [1]. The best approach is to use a structured solver that can operate on distributed stochastic programs, such as LShapedSolvers.jl or ProgressiveHedgingSolvers.jl."
},

{
    "location": "manual/structuredsolvers/#",
    "page": "Structured solvers",
    "title": "Structured solvers",
    "category": "page",
    "text": ""
},

{
    "location": "manual/structuredsolvers/#Structured-solvers-1",
    "page": "Structured solvers",
    "title": "Structured solvers",
    "category": "section",
    "text": "A stochastic program has a structure that can exploited in solver algorithms through decomposition. This can heavily reduce the computation time required to optimize the stochastic program, compared to solving the extensive form directly. Moreover, a distributed stochastic program is by definition decomposed and a structured solver that can operate in parallel will be much more efficient."
},

{
    "location": "manual/structuredsolvers/#Solver-interface-1",
    "page": "Structured solvers",
    "title": "Solver interface",
    "category": "section",
    "text": "The structured solver interface mimics that of MathProgBase, and it needs to be implemented by any structured solver to be compatible with StochasticPrograms. Define a new structured solver as a subtype of AbstractStructuredModel. Moreoever, define a shallow object of type AbstractStructuredSolver. This object is intended to be the interface to end users of the solver and is what should be passed to optimize!. Next, implement StructuredModel, that takes the stochastic program and the AbstractStructuredSolver object and return and instance of AbstractStructuredModel which internal state depends on the given stochastic program. Next, the solver algorithm should be run when calling optimize_structured! on the AbstractStructuredModel. After successfuly optimizing the model, the solver must be able to fill in the optimal solution in the first stage and all second stages through fill_solution!.Some procedures in StochasticPrograms require a MathProgBase solver. It is common that structured solvers rely internally on some MathProgBase solver. Hence, for convenience, a structured solver can implement internal_solver to return any internal MathProgBase solver. A stochastic program that has an loaded structured solver that implements this method can then make use of that solver for those procedures, instead of requiring an external solver to be supplied. Finally, a structured solver can optionally implement solverstr to return an informative description string for printouts.As an example, a simplified version of the implementation of the structured solver interface in LShapedSolvers.jl is given below:abstract AbstractLShapedSolver <: AbstractStructuredModel end\n\nconst MPB = MathProgBase\n\nmutable struct LShapedSolver <: AbstractStructuredSolver\n    lpsolver::MPB.AbstractMathProgSolver\n    subsolver::MPB.AbstractMathProgSolver\n    checkfeas::Bool\n    crash::Crash.CrashMethod\n    parameters::Dict{Symbol,Any}\n\n    function (::Type{LShapedSolver})(lpsolver::MPB.AbstractMathProgSolver; crash::Crash.CrashMethod = Crash.None(), subsolver::MPB.AbstractMathProgSolver = lpsolver, checkfeas::Bool = false, kwargs...)\n        return new(lpsolver, subsolver, checkfeas, crash, Dict{Symbol,Any}(kwargs))\n    end\nend\n\nfunction StructuredModel(stochasticprogram::StochasticProgram, solver::LShapedSolver)\n    x₀ = solver.crash(stochasticprogram, solver.lpsolver)\n    return LShaped(stochasticprogram, x₀, solver.lpsolver, solver.subsolver, solver.checkfeas; solver.parameters...)\nend\n\nfunction internal_solver(solver::LShapedSolver)\n    return solver.lpsolver\nend\n\nfunction optimize_structured!(lshaped::AbstractLShapedSolver)\n    return lshaped()\nend\n\nfunction fill_solution!(stochasticprogram::StochasticProgram, lshaped::AbstractLShapedSolver)\n    # First stage\n    first_stage = StochasticPrograms.get_stage_one(stochasticprogram)\n    nrows, ncols = first_stage_dims(stochasticprogram)\n    StochasticPrograms.set_decision!(stochasticprogram, decision(lshaped))\n    μ = try\n        MPB.getreducedcosts(lshaped.mastersolver.lqmodel)[1:ncols]\n    catch\n        fill(NaN, ncols)\n    end\n    StochasticPrograms.set_first_stage_redcosts!(stochasticprogram, μ)\n    λ = try\n        MPB.getconstrduals(lshaped.mastersolver.lqmodel)[1:nrows]\n    catch\n        fill(NaN, nrows)\n    end\n    StochasticPrograms.set_first_stage_duals!(stochasticprogram, λ)\n    # Second stage\n    fill_submodels!(lshaped, scenarioproblems(stochasticprogram))\nend"
},

{
    "location": "manual/structuredsolvers/#LShapedSolvers.jl-1",
    "page": "Structured solvers",
    "title": "LShapedSolvers.jl",
    "category": "section",
    "text": "LShapedSolvers is a collection of structured optimization algorithms for two-stage (L-shaped) stochastic recourse problems. All algorithm variants are based on the L-shaped method by Van Slyke and Wets. LShapedSolvers interfaces with StochasticPrograms through the structured solver interface. It is available as an unregistered package on Github, ans can be installed as follows:pkg> add https://github.com/martinbiel/LShapedSolvers.jlusing StochasticPrograms\n@scenario Simple = begin\n    q₁::Float64\n    q₂::Float64\n    d₁::Float64\n    d₂::Float64\nend\nξ₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)\nξ₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)\nsp = StochasticProgram([ξ₁, ξ₂])\n@first_stage sp = begin\n    @variable(model, x₁ >= 40)\n    @variable(model, x₂ >= 20)\n    @objective(model, Min, 100*x₁ + 150*x₂)\n    @constraint(model, x₁ + x₂ <= 120)\nend\n@second_stage sp = begin\n    @decision x₁ x₂\n    ξ = scenario\n    @variable(model, 0 <= y₁ <= ξ.d₁)\n    @variable(model, 0 <= y₂ <= ξ.d₂)\n    @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)\n    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)\n    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)\nendAs an example, we solve the simple problem introduced in the Quick start:using LShapedSolvers\nusing GLPKMathProgInterface\n\noptimize!(sp, solver = LShapedSolver(:ls, GLPKSolverLP()))L-Shaped Gap  Time: 0:00:01 (6 iterations)\n  Objective:       -855.8333333333358\n  Gap:             0.0\n  Number of cuts:  8\n:OptimalNote, that an LP capable AbstractMathProgSolver is required to solve emerging subproblems. The following variants of the L-shaped algorithm are implemented:L-shaped with multiple cuts (default)\nL-shaped with regularized decomposition: regularization = :rd\nL-shaped with trust region: regularization = :tr\nL-shaped with level sets: regularization = :lvNote, that :rd and :lv both require a QP capable AbstractMathProgSolver for the master problems. If not available, setting the linearize keyword to true is an alternative.In addition, there is a distributed variant of each algorithm, created by supplying distributed = true to the factory method. This requires adding processes with addprocs prior to execution. The distributed variants are designed for StochasticPrograms, and are most efficient when run on distributed stochastic programs.Each algorithm has a set of parameters that can be tuned prior to execution. For a list of these parameters and their default values, use ? in combination with the solver object. For example, ?LShaped gives the parameter list of the default L-shaped algorithm. For a list of all solvers and their handle names, use ?LShapedSolver."
},

{
    "location": "manual/structuredsolvers/#ProgressiveHedgingSolvers.jl-1",
    "page": "Structured solvers",
    "title": "ProgressiveHedgingSolvers.jl",
    "category": "section",
    "text": "ProgressiveHedgingSolvers includes implementations of the progressive-hedging algorithm for two-stage stochastic recourse problems. All algorithm variants are based on the original progressive-hedging algorithm by Rockafellar and Wets. ProgressiveHedgingSolvers interfaces with StochasticPrograms through the structured solver interface. It is available as an unregistered package on Github, ans can be installed as follows:pkg> add https://github.com/martinbiel/LShapedSolvers.jlAs an example, we solve the simple problem introduced in the Quick start:using ProgressiveHedgingSolvers\nusing Ipopt\n\noptimize!(sp, solver = ProgressiveHedgingSolver(:ph, IpoptSolver(print_level=0)))Progressive Hedging Time: 0:00:06 (1315 iterations)\n  Objective:  -855.8332803469448\n  δ:          9.570267362791345e-7\n:OptimalNote, that a QP capable AbstractMathProgSolver is required to solve emerging subproblems.An adaptive penalty parameter can be used by supplying penalty = :adaptive to the factory method.By default, the execution is :sequential. Supplying either execution = :synchronous or execution = :asynchronous to the factory method yields distributed variants of the algorithm. This requires adding processes with addprocs prior to execution. The distributed variants are designed for StochasticPrograms, and is most efficient when run on distributed stochastic programs.The algorithm variants has a set of parameters that can be tuned prior to execution. For a list of these parameters and their default values, use ? in combination with the solver object. For example, ?ProgressiveHedging gives the parameter list of the sequential progressive-hedging algorithm. For a list of all solvers and their handle names, use ?ProgressiveHedgingSolver."
},

{
    "location": "manual/examples/#",
    "page": "Examples",
    "title": "Examples",
    "category": "page",
    "text": ""
},

{
    "location": "manual/examples/#Examples-1",
    "page": "Examples",
    "title": "Examples",
    "category": "section",
    "text": ""
},

{
    "location": "manual/examples/#Farmer-problem-1",
    "page": "Examples",
    "title": "Farmer problem",
    "category": "section",
    "text": "The following defines the well-known \"Farmer problem\", first outlined in Introduction to Stochastic Programming, in StochasticPrograms. The problem revolves around a farmer who needs to decide how to partition his land to sow three different crops. The uncertainty comes from not knowing what the future yield of each crop will be. Recourse decisions involve purchasing/selling crops at the market.using StochasticPrograms\nusing GLPKMathProgInterfaceWe begin by introducing some variable indices:Crops = [:wheat, :corn, :beets];\nPurchased = [:wheat, :corn];\nSold = [:wheat,:corn,:beets_quota,:beets_extra];The price of beets drops after a certain quantity (6000), so we introduce an extra variable to handle the excess beets. Using the variable indices, we define the deterministic problem parameters:Cost = Dict(:wheat=>150, :corn=>230, :beets=>260);\nRequired = Dict(:wheat=>200, :corn=>240, :beets=>0);\nPurchasePrice = Dict(:wheat=>238, :corn=>210);\nSellPrice = Dict(:wheat=>170, :corn=>150, :beets_quota=>36, :beets_extra=>10);\nBudget = 500;In the first stage, the farmer needs to know what crops to plant, the cost of planting them, and the available land. Therefore, we introduce the first stage data:first_stage_data = (Crops, Cost, Budget)In the second stage, the farmer needs to know the required quantity of each crop, the purchase price, and the sell price:second_stage_data = (Required, PurchasePrice, SellPrice)The uncertainty lies in the future yield of each crop. We define a scenario type to capture this:@scenario Farmer = begin\n    Yield::Dict{Symbol, Float64}\n\n    @zero begin\n        return FarmerScenario(Dict(:wheat=>0., :corn=>0., :beets=>0.))\n    end\n\n    @expectation begin\n        return FarmerScenario(Dict(:wheat=>sum([probability(s)*s.Yield[:wheat] for s in scenarios]),\n                                   :corn=>sum([probability(s)*s.Yield[:corn] for s in scenarios]),\n                                   :beets=>sum([probability(s)*s.Yield[:beets] for s in scenarios])))\n    end\nendWe provide an implementation of expected since it can not be autogenerated for the internal Dict type. The three predicted outcomes can be defined through:s₁ = FarmerScenario(Dict(:wheat=>3.0,:corn=>3.6,:beets=>24.0), probability = 1/3)\ns₂ = FarmerScenario(Dict(:wheat=>2.5,:corn=>3.0,:beets=>20.0), probability = 1/3)\ns₃ = FarmerScenario(Dict(:wheat=>2.0,:corn=>2.4,:beets=>16.0), probability = 1/3)Now, we create a stochastic program with the defined data:farmer = StochasticProgram(first_stage_data, second_stage_data, [s₁,s₂,s₃], solver=GLPKSolverLP())Finally, we define the optimization models:@first_stage farmer = begin\n    (Crops,Cost,Budget) = stage\n    @variable(model, x[c = Crops] >= 0)\n    @objective(model, Min, sum(Cost[c]*x[c] for c in Crops))\n    @constraint(model, sum(x[c] for c in Crops) <= Budget)\nend\n@second_stage farmer = begin\n    @decision x\n    (Required, PurchasePrice, SellPrice) = stage\n    @variable(model, y[p = Purchased] >= 0)\n    @variable(model, w[s = Sold] >= 0)\n    @objective(model, Min, sum( PurchasePrice[p] * y[p] for p = Purchased) - sum( SellPrice[s] * w[s] for s in Sold))\n\n    @constraint(model, const_minreq[p=Purchased],\n                   scenario.Yield[p] * x[p] + y[p] - w[p] >= Required[p])\n    @constraint(model, const_minreq_beets,\n                   scenario.Yield[:beets] * x[:beets] - w[:beets_quota] - w[:beets_extra] >= Required[:beets])\n    @constraint(model, const_aux, w[:beets_quota] <= 6000)\nendWe can now optimize the model:optimize!(farmer)\nx = optimal_decision(farmer, :x)\nprintln(\"Wheat: $(x[:wheat])\")\nprintln(\"Corn: $(x[:corn])\")\nprintln(\"Beets: $(x[:beets])\")\nprintln(\"Profit: $(optimal_value(farmer))\")Finally, we calculate the stochastic performance of the model:println(\"EVPI: $(EVPI(farmer))\")\nprintln(\"VSS: $(VSS(farmer))\")"
},

{
    "location": "manual/examples/#Continuous-scenario-distribution-1",
    "page": "Examples",
    "title": "Continuous scenario distribution",
    "category": "section",
    "text": "As an example, consider the following generalized stochastic program:DeclareMathOperator*minimizeminimize\nbeginaligned\n minimize_x in mathbbR  quad operatornamemathbbE_omega left(x - xi(omega))^2right \nendalignedwhere xi(omega) is exponentially distributed. We will skip the mathematical details here and just take for granted that the optimizer to the above problem is the mean of the exponential distribution. We will try to approximately solve this problem using sample average approximation. First, lets try to introduce a custom discrete scenario type that models a stochastic variable with a continuous probability distribution. Consider the following implementation:using StochasticPrograms\nusing Distributions\n\nstruct DistributionScenario{D <: UnivariateDistribution} <: AbstractScenario\n    probability::Probability\n    distribution::D\n    ξ::Float64\n\n    function DistributionScenario(distribution::UnivariateDistribution, val::AbstractFloat)\n        return new{typeof(distribution)}(Probability(pdf(distribution, val)), distribution, Float64(val))\n    end\nend\n\nfunction StochasticPrograms.expected(scenarios::Vector{<:DistributionScenario{D}}) where D <: UnivariateDistribution\n    isempty(scenarios) && return DistributionScenario(D(), 0.0)\n    distribution = scenarios[1].distribution\n    return ExpectedScenario(DistributionScenario(distribution, mean(distribution)))\nendThe fallback probability method is viable as long as the scenario type contains a Probability field named probability. The implementation of expected is somewhat unconventional as it returns the mean of the distribution regardless of how many scenarios are given.We can implement a sampler that generates exponentially distributed scenarios as follows:struct ExponentialSampler <: AbstractSampler{DistributionScenario{Exponential{Float64}}}\n    distribution::Exponential\n\n    ExponentialSampler(θ::AbstractFloat) = new(Exponential(θ))\nend\n\nfunction (sampler::ExponentialSampler)()\n    ξ = rand(sampler.distribution)\n    return DistributionScenario(sampler.distribution, ξ)\nendNow, lets attempt to define the generalized stochastic program using the available modeling tools:using Ipopt\n\nmodel = StochasticModel((sp) -> begin\n	@first_stage sp = begin\n		@variable(model, x)\n	end\n\n	@second_stage sp = begin\n		@decision x\n		ξ = scenario.ξ\n		@variable(model, y)\n		@constraint(model, y == (x - ξ)^2)\n		@objective(model, Min, y)\n	end\nend)Stochastic Model\n\nminimize cᵀx + 𝔼[Q(x,ξ)]\n  x∈ℝⁿ  Ax = b\n         x ≥ 0\n\nwhere\n\nQ(x,ξ) = min  q(ξ)ᵀy\n        y∈ℝᵐ T(ξ)x + Wy = h(ξ)\n              y ≥ 0The mean of the given exponential distribution is 20, which is the optimal solution to the general problem. Now, lets create a finite SAA model of 1000 exponentially distributed numbers:sampler = ExponentialSampler(2.) # Create a sampler\n\nsaa = SAA(model, sampler, 1000) # Sample 1000 exponentially distributed scenarios and create an SAA modelStochastic program with:\n * 1000 scenarios of type DistributionScenario\n * 1 decision variable\n * 1 recourse variable\nSolver is default solverBy the law of large numbers, we approach the generalized formulation with increasing sample size. Solving yields:optimize!(saa, solver = IpoptSolver(print_level=0))\n\nprintln(\"Optimal decision: $(optimal_decision(saa))\")\nprintln(\"Optimal value: $(optimal_value(saa))\")Optimal decision: [2.07583]\nOptimal value: 4.00553678799426Now, due to the special implementation of the expected function, it actually holds that the expected value solution solves the generalized problem. Consider:println(\"EVP decision: $(EVP_decision(saa, solver = IpoptSolver(print_level=0)))\")\nprintln(\"VSS: $(VSS(saa, solver = IpoptSolver(print_level=0)))\")EVP decision: [2.0]\nVSS: 0.005750340653017716Accordingly, the VSS is small."
},

{
    "location": "library/public/#",
    "page": "Public interface",
    "title": "Public interface",
    "category": "page",
    "text": ""
},

{
    "location": "library/public/#Public-interface-1",
    "page": "Public interface",
    "title": "Public interface",
    "category": "section",
    "text": "Documentation for StochasticPrograms.jl\'s public interface."
},

{
    "location": "library/public/#Contents-1",
    "page": "Public interface",
    "title": "Contents",
    "category": "section",
    "text": "Pages = [\"public.md\"]"
},

{
    "location": "library/public/#Index-1",
    "page": "Public interface",
    "title": "Index",
    "category": "section",
    "text": "Pages = [\"public.md\"]\nOrder   = [:type, :macro, :function]"
},

{
    "location": "library/public/#StochasticPrograms.StochasticProgram",
    "page": "Public interface",
    "title": "StochasticPrograms.StochasticProgram",
    "category": "type",
    "text": "StochasticProgram{SD <: AbstractScenario}\n\nA mathematical model of a stochastic optimization problem. Every instance is linked to some given scenario type AbstractScenario. A StochasticProgram can be memory-distributed on multiple Julia processes.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.StochasticProgram-Tuple{Any,Any,Array{#s13,1} where #s13<:AbstractScenario}",
    "page": "Public interface",
    "title": "StochasticPrograms.StochasticProgram",
    "category": "method",
    "text": "StochasticProgram(first_stage_data::Any,\n                  second_stage_data::Any,\n                  scenarios::Vector{<:AbstractScenario};\n                  solver = JuMP.UnsetSolver(),\n                  procs = workers())\n\nCreate a new stochastic program with a given collection of scenarios\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.StochasticProgram-Tuple{Array{#s14,1} where #s14<:AbstractScenario}",
    "page": "Public interface",
    "title": "StochasticPrograms.StochasticProgram",
    "category": "method",
    "text": "StochasticProgram(scenarios::Vector{<:AbstractScenario};\n                  solver = JuMP.UnsetSolver(),\n                  procs = workers()) where {SD <: AbstractScenario}\n\nCreate a new stochastic program with a given collection of scenarios and no stage data.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.StochasticProgram-Union{Tuple{S}, Tuple{Any,Any,Type{S}}} where S<:AbstractScenario",
    "page": "Public interface",
    "title": "StochasticPrograms.StochasticProgram",
    "category": "method",
    "text": "StochasticProgram(first_stage_data::Any,\n                  second_stage_data::Any,\n                  ::Type{S};\n                  solver = JuMP.UnsetSolver(),\n                  procs = workers()) where {S <: AbstractScenario}\n\nCreate a new stochastic program with stage data given by first_stage_data and second_stage_data. After construction, scenarios of type S can be added through add_scenario!. Optionally, a capable solver can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting procs = [1].\n\n\n\n\n\n"
},

{
    "location": "library/public/#Constructors-1",
    "page": "Public interface",
    "title": "Constructors",
    "category": "section",
    "text": "Modules = [StochasticPrograms]\nPages   = [\"twostage.jl\"]"
},

{
    "location": "library/public/#StochasticPrograms.AbstractScenario",
    "page": "Public interface",
    "title": "StochasticPrograms.AbstractScenario",
    "category": "type",
    "text": "AbstractScenario\n\nAbstract supertype for scenario objects.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.ExpectedScenario",
    "page": "Public interface",
    "title": "StochasticPrograms.ExpectedScenario",
    "category": "type",
    "text": "ExpectedScenario{S <: AbstractScenario}\n\nWrapper type around an AbstractScenario. Should for convenience be used as the result of a call to expected.\n\nSee also expected\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.Probability",
    "page": "Public interface",
    "title": "StochasticPrograms.Probability",
    "category": "type",
    "text": "Probability\n\nA type-safe wrapper for Float64 used to represent probability of a scenario occuring.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.expected-Union{Tuple{Array{S,1}}, Tuple{S}} where S<:AbstractScenario",
    "page": "Public interface",
    "title": "StochasticPrograms.expected",
    "category": "method",
    "text": "expected(scenarios::Vector{<:AbstractScenario})\n\nReturn the expected scenario out of the collection scenarios in an ExpectedScenario wrapper.\n\nThis is defined through classical expectation: sum([probability(s)*s for s in scenarios]), and is always defined for scenarios created through @scenario, if the requested fields support it.\n\nOtherwise, user-defined scenario types must implement this method for full functionality.\n\nSee also ExpectedScenario\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.probability-Tuple{AbstractScenario}",
    "page": "Public interface",
    "title": "StochasticPrograms.probability",
    "category": "method",
    "text": "probability(scenario::AbstractScenario)\n\nReturn the probability of scenario occuring.\n\nIs always defined for scenarios created through @scenario. Other user defined scenario types must implement this method to generate a proper probability. The default behaviour is to assume that scenario has a probability field of type Probability\n\nSee also: Probability\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.probability-Tuple{Array{#s13,1} where #s13<:AbstractScenario}",
    "page": "Public interface",
    "title": "StochasticPrograms.probability",
    "category": "method",
    "text": "probability(scenarios::Vector{<:AbstractScenario})\n\nReturn the probability of that any scenario in the collection scenarios occurs.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.set_probability!-Tuple{AbstractScenario,AbstractFloat}",
    "page": "Public interface",
    "title": "StochasticPrograms.set_probability!",
    "category": "method",
    "text": "set_probability!(scenario::AbstractScenario, probability::AbstractFloat)\n\nSet the probability of scenario occuring.\n\nIs always defined for scenarios created through @scenario. Other user defined scenario types must implement this method.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.AbstractSampler",
    "page": "Public interface",
    "title": "StochasticPrograms.AbstractSampler",
    "category": "type",
    "text": "AbstractSampler\n\nAbstract supertype for sampler objects.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.sample",
    "page": "Public interface",
    "title": "StochasticPrograms.sample",
    "category": "function",
    "text": "sample(sampler::AbstractSampler{S})\n\nSample a scenario of type S using sampler.\n\n\n\n\n\nsample(sampler::AbstractSampler{S}, π::AbstractSampler)\n\nSample a scenario of type S using sampler and set the probability of the sampled scenario to π.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.@scenario",
    "page": "Public interface",
    "title": "StochasticPrograms.@scenario",
    "category": "macro",
    "text": "@scenario(def)\n\nDefine a scenario type compatible with StochasticPrograms using the syntax\n\n@scenario name = begin\n    ...structdef...\n\n    [@zero begin\n        ...\n        return zero(scenario)\n    end]\n\n    [@expectation begin\n        ...\n        return expected(scenarios)\n     end]\nend\n\nThe generated type is referenced through [name]Scenario and a default constructor is always generated. This constructor accepts the keyword probability to set the probability of the scenario occuring. Otherwise, any internal variables and specialized constructors are defined in the @scenario block as they would be in any Julia struct.\n\nIf possible, a zero method and an expected method will be generated for the defined type. Otherwise, or if the default implementation is not desired, these can be user provided through @zero and @expectation.\n\nThe defined scenario type will be available on all Julia processes.\n\nExamples\n\nThe following defines a simple scenario ξ with a single value.\n\n@scenario Example = begin\n    ξ::Float64\nend\n\nExampleScenario(1.0, probability = 0.5)\n\n# output\n\nExampleScenario with probability 0.5\n\n\nSee also: @zero, @expectation, @sampler\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.@zero",
    "page": "Public interface",
    "title": "StochasticPrograms.@zero",
    "category": "macro",
    "text": "@zero(def)\n\nDefine the additive zero scenario inside a @scenario block using the syntax:\n\n@zero begin\n    ...\n    return zero_scenario\nend\n\nExamples\n\nThe following defines a zero scenario for the example scenario defined in @scenario\n\n@zero begin\n    return ExampleScenario(0.0)\nend\n\nSee also @scenario\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.@expectation",
    "page": "Public interface",
    "title": "StochasticPrograms.@expectation",
    "category": "macro",
    "text": "@expectation(def)\n\nDefine how to form the expected scenario inside a @scenario block. The scenario collection is accessed through the reserved keyword scenarios.\n\n@zero begin\n    ...\n    return zero_scenario\nend\n\nExamples\n\nThe following defines expectation for the example scenario defined in @scenario\n\n@expectation begin\n    return ExampleScenario(sum([probability(s)*s.ξ for s in scenarios]))\nend\n\nSee also @scenario\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.@sampler",
    "page": "Public interface",
    "title": "StochasticPrograms.@sampler",
    "category": "macro",
    "text": "@sampler(def)\n\nDefine a sampler for some scenario type compatible with StochasticPrograms using the syntax\n\n@sampler [samplername] scenario = begin\n    ...internals...\n\n    @sample begin\n        ...\n        return scenario\n    end\nend\n\nAny internal state required by the sampler, as well as any specialized constructor, are defined in the @sampler block as they would be in any Julia struct. Define the sample operation inside the @sample block. Optionally, give a samplername to the sampler. Otherwise, it will be named [scenario]Sampler. The defined sampler will be available on all Julia processes.\n\nExamples\n\nThe following defines a simple dummy sampler, with some internal weight value, for the scenario defined in @scenario, and samples one scenario.\n\n@sampler Example = begin\n    w::Float64\n\n    Example(w::AbstractFloat) = new(w)\n\n    @sample begin\n        w = sampler.w\n        return ExampleScenario(w*randn(), probability = rand())\n    end\nend\ns = ExampleSampler(2.0)\ns()\n\n# output\n\nExampleScenario(Probability(0.29), 1.48)\n\n\nSee also: @sample, @scenario\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.@sample",
    "page": "Public interface",
    "title": "StochasticPrograms.@sample",
    "category": "macro",
    "text": "@sample(def)\n\nDefine the sample operation inside a @sampler block, using the syntax\n\n@sample begin\n    ...\n    return sampled_scenario\nend\n\nThe sampler object is referenced through the reserved keyword sampler, from which any internals can be accessed.\n\n\n\n\n\n"
},

{
    "location": "library/public/#Scenarios-1",
    "page": "Public interface",
    "title": "Scenarios",
    "category": "section",
    "text": "Modules = [StochasticPrograms]\nPages   = [\"scenario.jl\"]AbstractSampler\nsampleDocTestSetup = quote\n    using StochasticPrograms\nend@scenario\n@zero\n@expectation\n@sampler\n@sample"
},

{
    "location": "library/public/#StochasticPrograms.@first_stage",
    "page": "Public interface",
    "title": "StochasticPrograms.@first_stage",
    "category": "macro",
    "text": "@first_stage(def)\n\nAdd a first stage model generation recipe to stochasticprogram using the syntax\n\n@first_stage stochasticprogram::StochasticProgram = begin\n    ...\nend [defer]\n\nwhere JuMP syntax is used inside the block to define the first stage model. During definition, the first stage model is referenced through the reserved keyword model.\n\nOptionally, give the keyword defer after the  to delay generation of the first stage model.\n\nExamples\n\nThe following defines the first stage model given by:\n\n  minimize 100x₁ + 150x₂\n    st  x₁ + x₂  120\n         x₁  40\n         x₂  20\n\n@first_stage sp = begin\n    @variable(model, x₁ >= 40)\n    @variable(model, x₂ >= 20)\n    @objective(model, Min, 100*x₁ + 150*x₂)\n    @constraint(model, x₁ + x₂ <= 120)\nend\n\n# output\n\nStochastic program with:\n * 0 scenarios of type SimpleScenario\n * 2 decision variables\n * undefined second stage\nSolver is default solver\n\n\nSee also: @second_stage\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.@second_stage",
    "page": "Public interface",
    "title": "StochasticPrograms.@second_stage",
    "category": "macro",
    "text": "@second_stage(def)\n\nAdd a second stage model generation recipe to stochasticprogram using the syntax\n\n@second_stage stochasticprogram::StochasticProgram = begin\n    @decision var1 var2 ...\n    ...\nend [defer]\n\nwhere JuMP syntax is used inside the block to define the second stage model. Annotate each first stage decision that appears in the second stage model with @decision. During definition, the second stage model is referenced through the reserved keyword model and the scenario specific data is referenced through the reserved keyword scenario.\n\nOptionally, give the keyword defer after the  to delay generation of the first stage model.\n\nExamples\n\nThe following defines the second stage model given by:\n\n  minimize q₁(ξ)y₁ + q₂(ξ)y₂\n    st  6y₁ + 10y₂  60x₁\n         8y₁ + 5y₂  60x₂\n         0  y₁  d₁(ξ)\n         0  y₂  d₂(ξ)\n\nwhere q₁(ξ) q₂(ξ) d₁(ξ) d₂(ξ) depend on the scenario ξ and x₁ x₂ are first stage variables. Two scenarios are added so that two second stage models are generated.\n\n@second_stage sp = begin\n    @decision x₁ x₂\n    ξ = scenario\n    @variable(model, 0 <= y₁ <= ξ.d₁)\n    @variable(model, 0 <= y₂ <= ξ.d₂)\n    @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)\n    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)\n    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)\nend\n\n# output\n\nStochastic program with:\n * 2 scenarios of type SimpleScenario\n * 2 decision variables\n * 2 recourse variables\nSolver is default solver\n\n\nSee also: @first_stage\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.@decision",
    "page": "Public interface",
    "title": "StochasticPrograms.@decision",
    "category": "macro",
    "text": "@decision(def)\n\nAnnotate each first stage variable that appears in a @second_stage block, using the syntax\n\n@decision var1, var2, ...\n\nExamples\n\n@decision x₁, x₂\n\nSee also @second_stage\n\n\n\n\n\n"
},

{
    "location": "library/public/#Model-definition-1",
    "page": "Public interface",
    "title": "Model definition",
    "category": "section",
    "text": "DocTestSetup = quote\n    using StochasticPrograms\n    @scenario Simple = begin\n        q₁::Float64\n        q₂::Float64\n        d₁::Float64\n        d₂::Float64\n    end\n    s₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)\n    s₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)\n    sp = StochasticProgram([s₁,s₂])\n    @first_stage sp = begin\n        @variable(model, x₁ >= 40)\n        @variable(model, x₂ >= 20)\n        @objective(model, Min, 100*x₁ + 150*x₂)\n        @constraint(model, x₁ + x₂ <= 120)\n    end\nend@first_stage\n@second_stage\n@decision"
},

{
    "location": "library/public/#StochasticPrograms.add_scenario!-Tuple{Function,StochasticProgram,Integer}",
    "page": "Public interface",
    "title": "StochasticPrograms.add_scenario!",
    "category": "method",
    "text": "add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram; defer::Bool = false)\n\nStore the second stage scenario returned by scenariogenerator in the second stage of stochasticprogram in worker node w.\n\nIf defer is true, then model creation is deferred until generate!(stochasticprogram) is called.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.add_scenario!-Tuple{Function,StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.add_scenario!",
    "category": "method",
    "text": "add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram; defer::Bool = false)\n\nStore the second stage scenario returned by scenariogenerator in the second stage of stochasticprogram.\n\nIf defer is true, then model creation is deferred until generate!(stochasticprogram) is called. If the stochasticprogram is distributed, the scenario will be defined on the node that currently has the fewest scenarios.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.add_scenario!-Tuple{StochasticProgram,AbstractScenario,Integer}",
    "page": "Public interface",
    "title": "StochasticPrograms.add_scenario!",
    "category": "method",
    "text": "add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, w::Integer; defer::Bool = false)\n\nStore the second stage scenario in the second stage of stochasticprogram in worker node w.\n\nIf defer is true, then model creation is deferred until generate!(stochasticprogram) is called.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.add_scenario!-Tuple{StochasticProgram,AbstractScenario}",
    "page": "Public interface",
    "title": "StochasticPrograms.add_scenario!",
    "category": "method",
    "text": "add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario; defer::Bool = false)\n\nStore the second stage scenario in the second stage of stochasticprogram.\n\nIf defer is true, then model creation is deferred until generate!(stochasticprogram) is called. If the stochasticprogram is distributed, the scenario will be defined on the node that currently has the fewest scenarios.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.add_scenarios!-Tuple{Function,StochasticProgram,Integer,Integer}",
    "page": "Public interface",
    "title": "StochasticPrograms.add_scenarios!",
    "category": "method",
    "text": "add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, w::Integer; defer::Bool = false)\n\nGenerate n second-stage scenarios using scenariogeneratorand store in the second stage of stochasticprogram in worker node w.\n\nIf defer is true, then model creation is deferred until generate!(stochasticprogram) is called.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.add_scenarios!-Tuple{Function,StochasticProgram,Integer}",
    "page": "Public interface",
    "title": "StochasticPrograms.add_scenarios!",
    "category": "method",
    "text": "add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}; defer::Bool = false)\n\nGenerate n second-stage scenarios using scenariogeneratorand store in the second stage of stochasticprogram.\n\nIf defer is true, then model creation is deferred until generate!(stochasticprogram) is called. If the stochasticprogram is distributed, scenarios will be distributed evenly across workers.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.add_scenarios!-Tuple{StochasticProgram,Array{#s31,1} where #s31<:AbstractScenario,Integer}",
    "page": "Public interface",
    "title": "StochasticPrograms.add_scenarios!",
    "category": "method",
    "text": "add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, w::Integer; defer::Bool = false)\n\nStore the collection of second stage scenarios in the second stage of stochasticprogram in worker node w.\n\nIf defer is true, then model creation is deferred until generate!(stochasticprogram) is called.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.add_scenarios!-Tuple{StochasticProgram,Array{#s31,1} where #s31<:AbstractScenario}",
    "page": "Public interface",
    "title": "StochasticPrograms.add_scenarios!",
    "category": "method",
    "text": "add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}; defer::Bool = false)\n\nStore the collection of second stage scenarios in the second stage of stochasticprogram.\n\nIf defer is true, then model creation is deferred until generate!(stochasticprogram) is called. If the stochasticprogram is distributed, scenarios will be distributed evenly across workers.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.decision_length-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.decision_length",
    "category": "method",
    "text": "decision_length(stochasticprogram::StochasticProgram)\n\nReturn the length of the first stage decision in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.deferred-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.deferred",
    "category": "method",
    "text": "deferred(stochasticprogram::StochasticProgram)\n\nReturn true if stochasticprogram is not fully generated.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.distributed-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.distributed",
    "category": "method",
    "text": "distributed(stochasticprogram::StochasticProgram)\n\nReturn true if stochasticprogram is memory distributed. p\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.expected-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.expected",
    "category": "method",
    "text": "expected(stochasticprogram::StochasticProgram)\n\nReturn the exected scenario of all scenarios in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.first_stage_data-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.first_stage_data",
    "category": "method",
    "text": "first_stage_data(stochasticprogram::StochasticProgram)\n\nReturn the first stage data structure, if any exists, in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.first_stage_dims-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.first_stage_dims",
    "category": "method",
    "text": "first_stage_dims(stochasticprogram::StochasticProgram)\n\nReturn a the number of variables and the number of constraints in the the first stage of stochasticprogram as a tuple.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.first_stage_nconstraints-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.first_stage_nconstraints",
    "category": "method",
    "text": "first_stage_nconstraints(stochasticprogram::StochasticProgram)\n\nReturn the number of constraints in the the first stage of stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.generator-Tuple{StochasticProgram,Symbol}",
    "page": "Public interface",
    "title": "StochasticPrograms.generator",
    "category": "method",
    "text": "generator(stochasticprogram::StochasticProgram, key::Symbol)\n\nReturn the problem generator associated with key in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.has_generator-Tuple{StochasticProgram,Symbol}",
    "page": "Public interface",
    "title": "StochasticPrograms.has_generator",
    "category": "method",
    "text": "has_generator(stochasticprogram::StochasticProgram, key::Symbol)\n\nReturn true if a problem generator with key exists in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.instantiate-Tuple{StochasticModel,Any,Any,Array{#s31,1} where #s31<:AbstractScenario}",
    "page": "Public interface",
    "title": "StochasticPrograms.instantiate",
    "category": "method",
    "text": "instantiate(stochasticmodel::StochasticModel,\n            first_stage::Any,\n            second_stage::Any,\n            scenarios::Vector{<:AbstractScenario};\n            solver = JuMP.UnsetSolver(),\n            procs = workers())\n\nInstantate a new stochastic program using the model definition stored in stochasticmodel, the stage data given by first_stage and second_stage, and the given collection of scenarios.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.instantiate-Tuple{StochasticModel,Array{#s31,1} where #s31<:AbstractScenario}",
    "page": "Public interface",
    "title": "StochasticPrograms.instantiate",
    "category": "method",
    "text": "instantiate(stochasticmodel::StochasticModel,\n            scenarios::Vector{<:AbstractScenario};\n            solver = JuMP.UnsetSolver(),\n            procs = workers())\n\nInstantate a new stochastic program using the model definition stored in stochasticmodel, and the given collection of scenarios.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.internal_model-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.internal_model",
    "category": "method",
    "text": "internal_model(stochasticprogram::StochasticProgram)\n\nReturn the internal model of the solver object in stochasticprogram, after a call to optimize!(stochasticprogram).\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.masterterms-Tuple{StochasticProgram,Integer}",
    "page": "Public interface",
    "title": "StochasticPrograms.masterterms",
    "category": "method",
    "text": "masterterms(stochasticprogram::StochasticProgram, i::Integer)\n\nReturn the first stage terms appearing in scenario i in stochasticprogram.\n\nThe master terms are given in sparse format as an array of tuples (row,col,coeff) which specify the occurance of master problem variables in the second stage constraints.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.nscenarios-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.nscenarios",
    "category": "method",
    "text": "nscenarios(stochasticprogram::StochasticProgram)\n\nReturn the number of scenarios in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.nstages-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.nstages",
    "category": "method",
    "text": "nstages(stochasticprogram::StochasticProgram)\n\nReturn the number of stages in stochasticprogram. Will return 2 for two-stage problems.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.nsubproblems-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.nsubproblems",
    "category": "method",
    "text": "nsubproblems(stochasticprogram::StochasticProgram)\n\nReturn the number of subproblems in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.optimal_decision-Tuple{StochasticProgram,Integer,Symbol}",
    "page": "Public interface",
    "title": "StochasticPrograms.optimal_decision",
    "category": "method",
    "text": "optimal_decision(stochasticprogram::StochasticProgram, var::Symbol)\n\nReturn the optimal second stage variable var of stochasticprogram in the ith scenario, after a call to optimize!(stochasticprogram).\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.optimal_decision-Tuple{StochasticProgram,Integer}",
    "page": "Public interface",
    "title": "StochasticPrograms.optimal_decision",
    "category": "method",
    "text": "optimal_decision(stochasticprogram::StochasticProgram, i::Integer)\n\nReturn the optimal second stage decision of stochasticprogram in the ith scenario, after a call to optimize!(stochasticprogram).\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.optimal_decision-Tuple{StochasticProgram,Symbol}",
    "page": "Public interface",
    "title": "StochasticPrograms.optimal_decision",
    "category": "method",
    "text": "optimal_decision(stochasticprogram::StochasticProgram, var::Symbol)\n\nReturn the optimal first stage variable var of stochasticprogram, after a call to optimize!(stochasticprogram).\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.optimal_decision-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.optimal_decision",
    "category": "method",
    "text": "optimal_decision(stochasticprogram::StochasticProgram)\n\nReturn the optimal first stage decision of stochasticprogram, after a call to optimize!(stochasticprogram).\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.optimal_value-Tuple{StochasticProgram,Integer}",
    "page": "Public interface",
    "title": "StochasticPrograms.optimal_value",
    "category": "method",
    "text": "optimal_value(stochasticprogram::StochasticProgram, i::Integer)\n\nReturn the optimal value of the ith subproblem in stochasticprogram, after a call to optimize!(stochasticprogram).\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.optimal_value-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.optimal_value",
    "category": "method",
    "text": "optimal_value(stochasticprogram::StochasticProgram)\n\nReturn the optimal value of stochasticprogram, after a call to optimize!(stochasticprogram).\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.optimize!-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.optimize!",
    "category": "method",
    "text": "optimize!(sp::StochasticProgram; solver::SPSolverType = JuMP.UnsetSolver())\n\nOptimize sp after calls to @first_stage sp = begin ... end and second_stage sp = begin ... end, assuming scenarios are available.\n\ngenerate!(sp) is called internally, so deferred models can be passed. Optionally, supply an AbstractMathProgSolver or an AbstractStructuredSolver as solver. Otherwise, any previously set solver will be used.\n\nExamples\n\nThe following solves the stochastic program sp using the L-shaped algorithm.\n\nusing LShapedSolvers\nusing GLPKMathProgInterface\n\noptimize!(sp, solver = LShapedSolver(:ls, GLPKSolverLP()));\n\n# output\n\nL-Shaped Gap  Time: 0:00:01 (4 iterations)\n  Objective:       -855.8333333333339\n  Gap:             0.0\n  Number of cuts:  7\n:Optimal\n\nThe following solves the stochastic program sp using GLPK on the extended form.\n\nusing GLPKMathProgInterface\n\noptimize!(sp, solver = GLPKSolverLP())\n\n:Optimal\n\nSee also: VRP\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.probability-Tuple{StochasticProgram,Integer}",
    "page": "Public interface",
    "title": "StochasticPrograms.probability",
    "category": "method",
    "text": "probability(stochasticprogram::StochasticProgram)\n\nReturn the probability of scenario ith scenario in stochasticprogram occuring.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.probability-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.probability",
    "category": "method",
    "text": "probability(stochasticprogram::StochasticProgram)\n\nReturn the probability of any scenario in stochasticprogram occuring. A well defined model should return 1.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.recourse_length-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.recourse_length",
    "category": "method",
    "text": "recourse_length(stochasticprogram::StochasticProgram)\n\nReturn the length of the second stage decision in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.sample!-Union{Tuple{S}, Tuple{D₂}, Tuple{D₁}, Tuple{StochasticProgram{D₁,D₂,S,SP} where SP<:AbstractScenarioProblems{D₂,S},AbstractSampler{S},Integer}} where S<:AbstractScenario where D₂ where D₁",
    "page": "Public interface",
    "title": "StochasticPrograms.sample!",
    "category": "method",
    "text": "sample!(stochasticprogram::StochasticProgram, sampler::AbstractSampler, n::Integer; defer::Bool = false)\n\nSample n scenarios using sampler and add to stochasticprogram.\n\nIf defer is true, then model creation is deferred until generate!(stochasticprogram) is called. If the stochasticprogram is distributed, scenarios will be distributed evenly across workers.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.sampler-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.sampler",
    "category": "method",
    "text": "sampler(stochasticprogram::StochasticProgram)\n\nReturn the sampler object, if any, in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.scenario-Tuple{StochasticProgram,Integer}",
    "page": "Public interface",
    "title": "StochasticPrograms.scenario",
    "category": "method",
    "text": "scenario(stochasticprogram::StochasticProgram, i::Integer)\n\nReturn the ith scenario in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.scenarioproblems-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.scenarioproblems",
    "category": "method",
    "text": "scenarioproblems(stochasticprogram::StochasticProgram)\n\nReturn the scenario problems in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.scenarios-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.scenarios",
    "category": "method",
    "text": "scenarios(stochasticprogram::StochasticProgram)\n\nReturn an array of all scenarios in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.scenariotype-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.scenariotype",
    "category": "method",
    "text": "scenariotype(stochasticprogram::StochasticProgram)\n\nReturn the type of the scenario structure associated with stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.second_stage_data-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.second_stage_data",
    "category": "method",
    "text": "second_stage_data(stochasticprogram::StochasticProgram)\n\nReturn the second stage data structure, if any exists, in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.set_first_stage_data!-Tuple{StochasticProgram,Any}",
    "page": "Public interface",
    "title": "StochasticPrograms.set_first_stage_data!",
    "category": "method",
    "text": "set_first_stage_data!(stochasticprogram::StochasticProgram, data::Any)\n\nStore the first stage data in the first stage of stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.set_second_stage_data!-Tuple{StochasticProgram,Any}",
    "page": "Public interface",
    "title": "StochasticPrograms.set_second_stage_data!",
    "category": "method",
    "text": "set_second_stage_data!(stochasticprogram::StochasticProgram, data::Any)\n\nStore the second stage data in the second stage of stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.set_spsolver-Tuple{StochasticProgram,Union{AbstractMathProgSolver, AbstractStructuredSolver}}",
    "page": "Public interface",
    "title": "StochasticPrograms.set_spsolver",
    "category": "method",
    "text": "set_spsolver(stochasticprogram::StochasticProgram, spsolver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver})\n\nStore the stochastic program solver spsolver in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.spsolver-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.spsolver",
    "category": "method",
    "text": "spsolver(stochasticprogram::StochasticProgram)\n\nReturn the stochastic program solver spsolver in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.subproblem-Tuple{StochasticProgram,Integer}",
    "page": "Public interface",
    "title": "StochasticPrograms.subproblem",
    "category": "method",
    "text": "subproblem(stochasticprogram::StochasticProgram, i::Integer)\n\nReturn the ith subproblem in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.subproblems-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.subproblems",
    "category": "method",
    "text": "subproblems(stochasticprogram::StochasticProgram)\n\nReturn an array of all subproblems in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.generate!-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.generate!",
    "category": "method",
    "text": "generate!(stochasticprogram::StochasticProgram)\n\nGenerate the stochasticprogram after giving model definitions with @firststage and @secondstage.\n\nGenerate the first stage model once, and generate second stage models for each supplied scenario  that has not been considered yet.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.outcome_model-Tuple{StochasticProgram,AbstractScenario,AbstractArray{T,1} where T}",
    "page": "Public interface",
    "title": "StochasticPrograms.outcome_model",
    "category": "method",
    "text": "outcome_model(stochasticprogram::StochasticProgram,\n              scenario::AbstractScenario,\n              x::AbstractVector;\n              solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())\n\nReturn the resulting second stage model if x is the first stage decision in scenario ì, in stochasticprogram. Optionally, supply a capable solver to the outcome model.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.stage_two_model-Tuple{StochasticProgram,AbstractScenario}",
    "page": "Public interface",
    "title": "StochasticPrograms.stage_two_model",
    "category": "method",
    "text": "stage_two_model(stochasticprogram::StochasticProgram)\n\nReturn a generated second stage model corresponding to scenario, in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.confidence_interval-Union{Tuple{S}, Tuple{StochasticModel,AbstractSampler{S}}} where S<:AbstractScenario",
    "page": "Public interface",
    "title": "StochasticPrograms.confidence_interval",
    "category": "method",
    "text": "confidence_interval(stochasticmodel::StochasticModel,\n                    sampler::AbstractSampler;\n                    solver = JuMP.UnsetSolver(),\n                    confidence = 0.9,\n                    N = 100,\n                    M = 10)\n\nGenerate a confidence interval around the true optimum of stochasticprogram at level confidence, when the underlying scenario distribution is inferred by sampler.\n\nN is the size of the SAA models used to generate the interval and generally governs how tight it is. M is the amount of samples used to compute the lower bound.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.evaluate_decision-Tuple{StochasticProgram,AbstractArray{T,1} where T}",
    "page": "Public interface",
    "title": "StochasticPrograms.evaluate_decision",
    "category": "method",
    "text": "evaluate_decision(stochasticprogram::StochasticProgram,\n                  x::AbstractVector;\n                  solver = JuMP.UnsetSolver())\n\nEvaluate the first stage decision x in stochasticprogram.\n\nIn other words, evaluate the first stage objective at x and solve outcome models of x for every available scenario. Optionally, supply a capable solver to solve the outcome models. Otherwise, any previously set solver will be used.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.evaluate_decision-Tuple{StochasticProgram,AbstractScenario,AbstractArray{T,1} where T}",
    "page": "Public interface",
    "title": "StochasticPrograms.evaluate_decision",
    "category": "method",
    "text": "evaluate_decision(stochasticprogram::StochasticProgram,\n                  scenario::AbstractScenario,\n                  x::AbstractVector;\n                  solver = JuMP.UnsetSolver())\n\nEvaluate the result of taking the first stage decision x if scenario is the actual outcome in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.evaluate_decision-Union{Tuple{S}, Tuple{StochasticModel,AbstractArray{T,1} where T,AbstractSampler{S}}} where S<:AbstractScenario",
    "page": "Public interface",
    "title": "StochasticPrograms.evaluate_decision",
    "category": "method",
    "text": "evaluate_decision(stochasticmodel::StochasticModel,\n                  x::AbstractVector,\n                  sampler::AbstractSampler;\n                  solver = JuMP.UnsetSolver(),\n                  confidence = 0.95,\n                  N = 1000)\n\nReturn a statistical estimate of the objective of stochasticprogram at x, and an upper bound at level confidence, when the underlying scenario distribution is inferred by sampler.\n\nIn other words, evaluate x on an SAA model of size N. Generate an upper bound using the sample variance of the evaluation.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.lower_bound-Union{Tuple{S}, Tuple{StochasticModel,AbstractSampler{S}}} where S<:AbstractScenario",
    "page": "Public interface",
    "title": "StochasticPrograms.lower_bound",
    "category": "method",
    "text": "lower_bound(stochasticmodel::StochasticModel,\n            sampler::AbstractSampler;\n            solver = JuMP.UnsetSolver(),\n            confidence = 0.95,\n            N = 100,\n            M = 10)\n\nGenerate a lower bound of the true optimum of stochasticprogram at level confidence, when the underlying scenario distribution is inferred by sampler.\n\nIn other words, solve and evaluate M SAA models of size N to generate a statistic estimate.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.stage_one_model-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.stage_one_model",
    "category": "method",
    "text": "stage_one_model(stochasticprogram::StochasticProgram)\n\nReturn a generated copy of the first stage model in stochasticprogram.\n\n\n\n\n\n"
},

{
    "location": "library/public/#API-1",
    "page": "Public interface",
    "title": "API",
    "category": "section",
    "text": "DocTestSetup = quote\n    using StochasticPrograms\n	@scenario Simple = begin\n		q₁::Float64\n		q₂::Float64\n		d₁::Float64\n		d₂::Float64\n	end\n	s₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)\n	s₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)\n    sp = StochasticProgram([s₁,s₂])\n    @first_stage sp = begin\n        @variable(model, x₁ >= 40)\n        @variable(model, x₂ >= 20)\n        @objective(model, Min, 100*x₁ + 150*x₂)\n        @constraint(model, x₁ + x₂ <= 120)\n    end\n    @second_stage sp = begin\n        @decision x₁ x₂\n        ξ = scenario\n        @variable(model, 0 <= y₁ <= ξ.d₁)\n        @variable(model, 0 <= y₂ <= ξ.d₂)\n        @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)\n        @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)\n        @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)\n    end\nendModules = [StochasticPrograms]\nPages   = [\"api.jl\", \"generation.jl\", \"evaluation.jl\"]"
},

{
    "location": "library/public/#StochasticPrograms.DEP-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.DEP",
    "category": "method",
    "text": "DEP(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())\n\nGenerate the deterministically equivalent problem (DEP) of the stochasticprogram.\n\nIn other words, generate the extended form the stochasticprogram as a single JuMP model. Optionally, a capable solver can be supplied to DEP. Otherwise, any previously set solver will be used.\n\nSee also: VRP, WS\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.EEV-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.EEV",
    "category": "method",
    "text": "EEV(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())\n\nCalculate the expected value of using the expected value solution (EEV) in stochasticprogram.\n\nIn other words, evaluate the EVP decision. Optionally, supply a capable solver to solve the intermediate problems. The default behaviour is to rely on any previously set solver.\n\nSee also: EVP, EV\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.EV-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.EV",
    "category": "method",
    "text": "EV(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())\n\nCalculate the optimal value of the EVP in stochasticprogram.\n\nOptionally, supply a capable solver to solve the expected value problem. The default behaviour is to rely on any previously set solver.\n\nSee also: EVP, EVP_decision, EEV\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.EVP-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.EVP",
    "category": "method",
    "text": "EVP(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())\n\nGenerate the expected value problem (EVP) in stochasticprogram.\n\nIn other words, generate a wait-and-see model corresponding to the expected scenario over all available scenarios in stochasticprogram. Optionally, supply a capable solver to EVP. Otherwise, any previously set solver will be used.\n\nSee also: EVP_decision, EEV, EV, WS\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.EVPI-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.EVPI",
    "category": "method",
    "text": "EVPI(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())\n\nCalculate the expected value of perfect information (EVPI) of the stochasticprogram.\n\nIn other words, calculate the gap between VRP and EWS. Optionally, supply a capable solver to solve the intermediate problems. Otherwise, any previously set solver will be used.\n\nSee also: VRP, EWS, VSS\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.EVP_decision-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.EVP_decision",
    "category": "method",
    "text": "EVP_decision(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())\n\nCalculate the optimizer of the EVP in stochasticprogram.\n\nOptionally, supply a capable solver to solve the expected value problem. The default behaviour is to rely on any previously set solver.\n\nSee also: EVP, EV, EEV\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.EWS-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.EWS",
    "category": "method",
    "text": "EWS(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())\n\nCalculate the expected wait-and-see result (EWS) of the stochasticprogram.\n\nIn other words, calculate the expectated result of all possible wait-and-see models, using the provided scenarios in stochasticprogram. Optionally, a capable solver can be supplied to solve the intermediate problems. Otherwise, any previously set solver will be used.\n\nSee also: VRP, WS\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.SAA-Union{Tuple{S}, Tuple{D₂}, Tuple{D₁}, Tuple{StochasticProgram{D₁,D₂,S,SP} where SP<:AbstractScenarioProblems{D₂,S},AbstractSampler{S},Integer}} where S<:AbstractScenario where D₂ where D₁",
    "page": "Public interface",
    "title": "StochasticPrograms.SAA",
    "category": "method",
    "text": "SAA(stochasticprogram::StochasticProgram, sampler::AbstractSampler, n::Integer; solver = JuMP.UnsetSolver())\n\nGenerate a sample average approximation (SAA) of size n for the stochasticprogram using the sampler.\n\nIn other words, sample n scenarios, of type consistent with stochasticprogram, and return the resulting stochastic program instance. Optionally, a capable solver can be supplied to SAA. Otherwise, any previously set solver will be used.\n\nSee also: sample!\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.SAA-Union{Tuple{S}, Tuple{StochasticModel,AbstractSampler{S},Integer}} where S<:AbstractScenario",
    "page": "Public interface",
    "title": "StochasticPrograms.SAA",
    "category": "method",
    "text": "SAA(stochasticmodel::StochasticModel, sampler::AbstractSampler, n::Integer; solver = JuMP.UnsetSolver())\n\nGenerate a sample average approximation (SAA) instance of size n using the model stored in stochasticmodel, and the provided sampler.\n\nOptionally, a capable solver can be supplied to SAA. Otherwise, any previously set solver will be used.\n\nSee also: sample!\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.SAA-Union{Tuple{S}, Tuple{StochasticModel,Any,Any,AbstractSampler{S},Integer}} where S<:AbstractScenario",
    "page": "Public interface",
    "title": "StochasticPrograms.SAA",
    "category": "method",
    "text": "SAA(stochasticmodel::StochasticModel, first_stage::Any, second_stage::Any, sampler::AbstractSampler, n::Integer; solver = JuMP.UnsetSolver())\n\nGenerate a sample average approximation (SAA) instance of size n using the model stored in stochasticmodel, the stage data given by first_stage and second_stage, and the provided sampler.\n\nOptionally, a capable solver can be supplied to SAA. Otherwise, any previously set solver will be used.\n\nSee also: sample!\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.VRP-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.VRP",
    "category": "method",
    "text": "VRP(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())\n\nCalculate the value of the recouse problem (VRP) in stochasticprogram.\n\nIn other words, optimize the stochastic program and return the optimal value. Optionally, supply a capable solver to optimize the stochastic program. Otherwise, any previously set solver will be used.\n\nSee also: EVPI, EWS\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.VSS-Tuple{StochasticProgram}",
    "page": "Public interface",
    "title": "StochasticPrograms.VSS",
    "category": "method",
    "text": "VSS(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())\n\nCalculate the value of the stochastic solution (VSS) of the stochasticprogram.\n\nIn other words, calculate the gap between EEV and VRP. Optionally, supply a capable solver to solve the intermediate problems. The default behaviour is to rely on any previously set solver.\n\n\n\n\n\n"
},

{
    "location": "library/public/#StochasticPrograms.WS-Tuple{StochasticProgram,AbstractScenario}",
    "page": "Public interface",
    "title": "StochasticPrograms.WS",
    "category": "method",
    "text": "WS(stochasticprogram::StochasticProgram, scenario::AbstractScenarioaDta; solver = JuMP.UnsetSolver())\n\nGenerate a wait-and-see (WS) model of the stochasticprogram, corresponding to scenario.\n\nIn other words, generate the first stage and the second stage of the stochasticprogram as if scenario is known to occur. Optionally, a capable solver can be supplied to WS. Otherwise, any previously set solver will be used.\n\nSee also: DEP, EVP\n\n\n\n\n\n"
},

{
    "location": "library/public/#Stochastic-programming-constructs-1",
    "page": "Public interface",
    "title": "Stochastic programming constructs",
    "category": "section",
    "text": "Modules = [StochasticPrograms]\nPages   = [\"spconstructs.jl\"]"
},

{
    "location": "library/solverinterface/#",
    "page": "Solver interface",
    "title": "Solver interface",
    "category": "page",
    "text": ""
},

{
    "location": "library/solverinterface/#Solver-interface-1",
    "page": "Solver interface",
    "title": "Solver interface",
    "category": "section",
    "text": "Documentation for StochasticPrograms.jl\'s interface for structured solvers."
},

{
    "location": "library/solverinterface/#Index-1",
    "page": "Solver interface",
    "title": "Index",
    "category": "section",
    "text": "Pages = [\"solverinterface.md\"]"
},

{
    "location": "library/solverinterface/#StochasticPrograms.AbstractStructuredSolver",
    "page": "Solver interface",
    "title": "StochasticPrograms.AbstractStructuredSolver",
    "category": "type",
    "text": "AbstractScenario\n\nAbstract supertype for structured solver interface objects.\n\n\n\n\n\n"
},

{
    "location": "library/solverinterface/#StochasticPrograms.AbstractStructuredModel",
    "page": "Solver interface",
    "title": "StochasticPrograms.AbstractStructuredModel",
    "category": "type",
    "text": "AbstractStructuredModel\n\nAbstract supertype for structured solver objects.\n\n\n\n\n\n"
},

{
    "location": "library/solverinterface/#StochasticPrograms.StructuredModel-Tuple{StochasticProgram,AbstractStructuredSolver}",
    "page": "Solver interface",
    "title": "StochasticPrograms.StructuredModel",
    "category": "method",
    "text": "StructuredModel(stochasticprogram::StochasticProgram, solver::AbstractStructuredSolver)\n\nReturn an instance of AbstractStructuredModel based on stochasticprogram and the given solver.\n\nSee also: optimize_structured!, fill_solution!\n\n\n\n\n\n"
},

{
    "location": "library/solverinterface/#StochasticPrograms.fill_solution!-Tuple{StochasticProgram,AbstractStructuredModel}",
    "page": "Solver interface",
    "title": "StochasticPrograms.fill_solution!",
    "category": "method",
    "text": "fill_solution!(stochasticprogram::StochasticProgram, structuredmodel::AbstractStructuredModel)\n\nFill in the optimal solution in stochasticprogram after a call to optimize_structured!. Should fill in the first stage result and second stage results for each available scenario.\n\nSee also: optimize_structured!\n\n\n\n\n\n"
},

{
    "location": "library/solverinterface/#StochasticPrograms.internal_solver-Tuple{AbstractStructuredSolver}",
    "page": "Solver interface",
    "title": "StochasticPrograms.internal_solver",
    "category": "method",
    "text": "internal_solver(solver::AbstractStructuredSolver)\n\nReturn an AbstractMathProgSolver, if available, from solver.\n\n\n\n\n\n"
},

{
    "location": "library/solverinterface/#StochasticPrograms.optimize_structured!-Tuple{AbstractStructuredModel}",
    "page": "Solver interface",
    "title": "StochasticPrograms.optimize_structured!",
    "category": "method",
    "text": "optimize_structured!(structuredmodel::AbstractStructuredModel)\n\nOptimize the AbstractStructuredModel, which also optimizes the stochasticprogram it was instansiated from.\n\nSee also: fill_solution!\n\n\n\n\n\n"
},

{
    "location": "library/solverinterface/#StochasticPrograms.solverstr-Tuple{AbstractStructuredModel}",
    "page": "Solver interface",
    "title": "StochasticPrograms.solverstr",
    "category": "method",
    "text": "solverstr(solver::AbstractStructuredModel)\n\nOptionally, return a string identifier of AbstractStructuredModel.\n\n\n\n\n\n"
},

{
    "location": "library/solverinterface/#Interface-1",
    "page": "Solver interface",
    "title": "Interface",
    "category": "section",
    "text": "AbstractStructuredSolver\nAbstractStructuredModelModules = [StochasticPrograms]\nPages   = [\"spinterface.jl\"]"
},

]}
