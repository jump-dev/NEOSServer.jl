# NEOS.jl
[![Build Status](https://travis-ci.org/odow/NEOS.jl.svg?branch=master)](https://travis-ci.org/odow/NEOS.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/u54uaoskgjd87gxb/branch/master?svg=true)](https://ci.appveyor.com/project/odow/neos-jl/branch/master)
[![codecov.io](http://codecov.io/github/odow/NEOS.jl/coverage.svg?branch=master)](http://codecov.io/github/odow/NEOS.jl?branch=master)

The [NEOS Server](http://www.neos-server.org/neos) is a free internet-based service for solving numerical optimization problems. It is able to take models specified in a variety of formats (including [AMPL](http://ampl.com/), [GAMS](http://www.gams.com/) and [MPS](https://en.wikipedia.org/wiki/MPS_%28format%29)) and pass them to a range of both free and commercial solvers (including [Gurobi](http://www.gurobi.com/), [CPLEX](http://www-03.ibm.com/software/products/en/ibmilogcpleoptistud/) and [Cbc](https://projects.coin-or.org/Cbc)). See [here](http://www.neos-server.org/neos/solvers/index.html) for the full list of solvers and input formats that NEOS supports.

NEOS is particularly useful if you require a commercial solver, but are unable to afford the subscription, or are not eligible for a free license, or if your problem is larger than the limits placed on free versions.

### Terms of use
As part of the [NEOS Server terms of use](http://www.neos-server.org/neos/termofuse.html), all models submitted to its solvers become part of the Public Domain.

## Installation

This package is currently upgrading to interface with the NEOS NL file-format API. You will need to run the following commands to get the latest version:

```julia
Pkg.add("NEOS")
Pkg.checkout("NEOS")
```

## The NEOS API
This package contains an interface for the [NEOS XML-RPC API](http://www.neos-server.org/neos/NEOS-API.html).

The following example shows how you can interact with the API.

```julia
using NEOS
# Some solvers require the user to supply a valid email address
neos_server = NEOSServer(email="me@mydomain.com")

# Prints the NEOS Welcome message
println(welcome(neos_server))

# Get an XML template
xml_string = getSolverTemplate(neos_server, "milp", "Cbc", "AMPL")

#
# Modify template with problem data
#

# Submit the XML job to NEOS
job = submitJob(neos_server, xml_string)

# Get the status of the Job from NEOS
status = getJobStatus(neos_server, job.number, job.password)

results = getFinalResults(neos_server, job.number, job.password)
```

## Integration with JuMP and MathProgBase
[JuMP](https://github.com/JuliaOpt/JuMP.jl) is a mathematical modelling language for Julia. It provides a solver independent way of writing optmisation models. To use NEOS via JuMP set the solver to `NEOSSolver(solver=<solver>, format=<:MPS | :NL>)` where `<solver>` is one of `:CPLEX`, `:MOSEK`, `:SYMPHONY`, or `:Xpress`, and `format` is either `:MPS` or `:NL`. For example:

```julia
using JuMP, NEOS

m = Model(solver=NEOSSolver(solver=:CPLEX, format=:MPS))

# Model definition

solve(m)
```

 The [MathProgBase](https://github.com/JuliaOpt/MathProgBase.jl) interface is a lowerlevel interface than JuMP that is also solver independent. To use NEOS in MathProgBase:

```julia
using MathProgBase, NEOS

mixintprog(..., NEOSSolver(solver=:CPLEX, format=:MPS))
```

## Supported Solvers
We currently support a limited range of the available NEOS Solvers due to the need to write a separate parser and submission form for each.

Here is a summary of the solvers and the features they currently support

| Solver      | Format | Requires Email | Type   | Special Ordered Sets |
| ----------- | ------ | :------------: | :----- | :---: |
| `:CPLEX`    | `:MPS` | yes            |  MILP  | yes   |
| `:CPLEX`    | `:NL`  | yes            |  MILP  | no    |
| `:MOSEK`    | `:MPS` | no             |  MILP  | no    |
| `:SYMPHONY` | `:MPS` | no             |  MIP   | no    |
| `:Xpress`   | `:MPS` | yes            |  MIP   | yes   |

*Note*: both `:CPLEX` and `:Xpress` require the user to supply a valid email address. i.e:
```julia
s = NEOSSolver(solver=:CPLEX, email="me@domain.com")
# or
s = NEOSSolver(solver=:CPLEX)
addemail!(s, "me@domain.com")
```

You can initialise the solver using a number of common, and solver-specific keyword arguments. The common parameters are:
 - `email`: valid email address. For example: `email="me@mydomain.com"`
 - `gzipmodel`: set `true` to gzip to MPS model. This reduces bandwith but takes a little longer to create. This defaults to `true`. i.e. `gzipmodel=false`
 - `print_results`: set `true` to print the NEOS results to `STDOUT`. This defaults to `false`. i.e. `print_results=true`
 - `result_file`: the full filename save NEOS results to. i.e. `result_file = "~/neos_results.txt"`

Some examples include
```julia
# An interface to the CPLEX solver on NEOS via the MPS format
NEOSSolver(solver=:CPLEX, email="me@mydomain.com")

# An interface to the CPLEX solver on NEOS via the NL format
NEOSSolver(solver=:CPLEX, format=:NL, email="me@mydomain.com")

# An interface to the MOSEK solver on NEOS
NEOSSolver(solver=:MOSEK)

# An interface to the COIN-OR SYMPHONY solver on NEOS
NEOSSolver(solver=:SYMPHONY)

# An interface to the XpressMP solver on NEOS
NEOSSolver(solver=:Xpress, gzipmodel=false, print_results=true)
 ```


## Parameters

You can set solver specific parameters using

```julia
addparameter!(solver, param::String, value)
```

or by using keyword arguments.

Solver specific examples include:

#### CPLEX
A list of parameters can be found [here](http://www-01.ibm.com/support/knowledgecenter/SSSA5P_12.6.1/ilog.odms.cplex.help/CPLEX/InteractiveOptimizer/topics/commands.html)
```julia
# these are the commands that you would type into the interactive optimiser
# 	"set <param> <value>"
s =  NEOSSolver(solver=:CPLEX)
addparameter!(s, "timelimit", 60)
# or
s = NEOSSolver(solver=:CPLEX, timelimit=60)
```

#### MOSEK
A list of parameters can be found [here](http://docs.mosek.com/7.0/capi/Parameters.html)
```julia
s = NEOSSolver(solver=:MOSEK)
addparameter!(s, "MSK_DPAR_OPTIMIZER_MAX_TIME", 60)
# or
s = NEOSSolver(solver=:MOSEK, MSK_DPAR_OPTIMIZER_MAX_TIME=60)
```

#### SYMPHONY
A list of parameters can be found [here](http://www.coin-or.org/SYMPHONY/man-5.6/node273.html#params)
```julia
# these are often of the form
# 	"<param> <value>"
s = NEOSSolver(solver=:SYMPHONY)
addparameter!(s, "time_limit", 60)
# or
s = NEOSSolver(solver=:SYMPHONY, time_limit=60)
```

#### Xpress
A list of parameters can be found [here](http://tomopt.com/docs/xpress/tomlab_xpress008.php)
```julia
# these are often of the form
# 	"<param>=<value>"
s = NEOSSolver(solver=:Xpress)
addparameter!(s, "MAXTIME", 60)
# or
s = NEOSSolver(solver=:Xpress, MAXTIME=60)
```
