# NEOS.jl
[![Build Status](https://travis-ci.org/odow/NEOS.jl.svg?branch=master)](https://travis-ci.org/odow/NEOS.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/u54uaoskgjd87gxb/branch/master?svg=true)](https://ci.appveyor.com/project/odow/neos-jl/branch/master)

The [NEOS Server](http://www.neos-server.org/neos) is a free internet-based service for solving numerical optimization problems. It is able to take models specified in a variety of formats (including [AMPL](http://ampl.com/), [GAMS](http://www.gams.com/) and [MPS](https://en.wikipedia.org/wiki/MPS_%28format%29)) and pass them to a range of both free and commercial solvers (including [Gurobi](http://www.gurobi.com/), [CPLEX](http://www-03.ibm.com/software/products/en/ibmilogcpleoptistud/) and [Cbc](https://projects.coin-or.org/Cbc)). See [here](http://www.neos-server.org/neos/solvers/index.html) for the full list of solvers and input formats that NEOS supports.

NEOS is particularly useful if you require a commercial solver, but are unable to afford the subscription, or are not eligible for a free license, or if you problem is larger than the limits placed on free versions. 

### Terms of use
As part of the [NEOS Server terms of use](http://www.neos-server.org/neos/termofuse.html), all models submitted to its solvers become part of the Public Domain.

## Installation
This package is not yet listed in `METADATA.jl`. To install it, run 

```julia
Pkg.clone("https://github.com/odow/NEOS.jl.git")
```

## The NEOS API
This package contains an interface for the [NEOS XML-RPC API](http://www.neos-server.org/neos/NEOS-API.html).

The following example shows how you can interact with the API.

```julia
using NEOS
neos_solver = NEOSSolver()

println(NEOS.welcome(neos_solver))

xml_string = getSolverTemplate(neos_solver, :MILP, :Cbc, :AMPL)

# Modify template with problem data

job = NEOS.submitJob(neos_solver, xml_string)
status = NEOS.getJobStatus(neos_solver, job.number, job.password)
```

## Integration with JuMP and MathProgBase
[JuMP](https://github.com/JuliaOpt/JuMP.jl) is a mathematical modelling language for Julia. It provides a solver independent way of writing optmisation models. To use NEOS via JuMP:

```julia
using JuMP, NEOS

m = Model(solver=NEOSSolver())

# Model definition

solve(m)
```

 The [MathProgBase](https://github.com/JuliaOpt/MathProgBase.jl) interface is a lowerlevel interface than JuMP that is also solver independent. To use NEOS in MathProgBase:

```julia
using MathProgBase, NEOS

mixintprog(..., NEOSSolver())

```

### How it works

NEOS.jl takes in a compliant MathProgBase model and converts it into an MPS file. This is then sent to the NEOS server, the resulting output file (plain text) is then parsed to extract the solution data.


## Supported Solvers
We currently support a limited range of the available NEOS Solvers due to the need to write a separate parser and submission form for each.

You can initialise the solver using 

```julia
NEOSSolver(solver=<SOLVER>, category=<CATEGORY>, email=<EMAIL>, resultdirectory=<"path/to/directory">)
```
where `<SOLVER>` is one of `:CPLEX`, `:scip`, `:SYMPHONY`, `:XpressMP`. Category is either `:MILP` (Mixed Integer Linear Program) or `:LP` (Linear Program). The default solver is `:SYMPHONY` and the default category is `:MILP`. If the keyword `resultdirectory` is specified then the results from NEOS will be additionally written to the file `<resultdirectory>/<jobnumber>.txt`.

Here is a summary of the solvers currently supported

| Solver    | Categories | Requires Email |
| ----------|:----------| :--------------:|
| `:CPLEX`    | `:MILP`, `:LP` |  yes|
| `:scip`     | `:MILP`      |  no|
| `:SYMPHONY` | `:MILP`      |  no|
| `:XpressMP` | `:MILP`      |  yes|

A few examples:
```julia
NEOSSolver()                 # defaults to solver=:SYMPHONY, category=:MILP, email left blank
NEOSSolver(solver=:scip) # category defaults to :MILP, email left blank
NEOSSolver(solver=:CPLEX, category=:LP, email="myname@mydomain.com")
NEOSSolver(solver=:XpressMP, email="myname@mydomain.com", resultdirectory="~/NEOS/")
```

*Note*: both `:CPLEX` and `:XpressMP` require the user to supply a valid email address. Therefore:
```julia
NEOSSolver(solver=:CPLEX)
# or
NEOSSolver(solver=:XpressMP)
```
will result in an error.

## Parameters

You can set solver specific parameters using

```julia
addParameter!(n::NEOSSolver, param::String)
```

or by using the `params` keyword argument when initialising the `NEOSSolver`.

```julia
NEOSSolver(solver=:SOLVER, params=["<param1>", "<param2>"])
```

Each `param` string is what you would type on a single line of a parameter file that is submitted to NEOS.

Solver specific examples include:

#### CPLEX
A list of parameters can be found [here](http://www-01.ibm.com/support/knowledgecenter/SSSA5P_12.6.1/ilog.odms.cplex.help/CPLEX/InteractiveOptimizer/topics/commands.html)
```julia
n = NEOSSolver(solver=:CPLEX)
# these are the commands that you would type into the interactive optimiser
# 	"set <param> <value>"
addParameter!(n, "set timelimit 60")

# or 

n = NEOSSolver(solver=:CPLEX, params=["set timelimit 60"])
```

#### SCIP
A list of parameters can be found [here](http://plato.asu.edu/milp/scip.sets)
```julia
n = NEOSSolver(solver=:scip)
# these are often of the form
# 	"<param>/<param>=<value>"
addParameter!(n, "limits/time = 60")

# or 

n = NEOSSolver(solver=:scip, params=["limits/time = 60"])
```

#### SYMPHONY
A list of parameters can be found [here](http://www.coin-or.org/SYMPHONY/man-5.6/node273.html#params)
```julia
n = NEOSSolver(solver=:SYMPHONY)
# these are often of the form
# 	"<param> <value>"
addParameter!(n, "time_limit 60")

# or 

n = NEOSSolver(solver=:SYMPHONY, params=["time_limit 60"])
```

#### XpressMP
A list of parameters can be found [here](http://tomopt.com/docs/xpress/tomlab_xpress008.php)
```julia
n = NEOSSolver(solver=:XpressMP)
# these are often of the form
# 	"<param>=<value>"
addParameter!(n, "MAXTIME=60")

# or 

n = NEOSSolver(solver=:XpressMP, params=[""MAXTIME=60"])
```
