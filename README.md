# NEOS.jl
[![Build Status](https://travis-ci.org/odow/NEOS.jl.svg?branch=master)](https://travis-ci.org/odow/NEOS.jl)

The [NEOS Server](http://www.neos-server.org/neos) is a free internet-based service for solving numerical optimization problems. It is able to take models specified in a variety of formats (including AMPL, GAMS and MPS) and pass them to a range of both free and commercial solvers (including Gurobi, CPLEX and Cbc). See [here](http://www.neos-server.org/neos/solvers/index.html) for the full list of solvers and input formats.

NEOS is particularly useful if you require a commercial solver, but are unable to afford the subscription, or are not eligible for a free license, or if you problem is larger than the limits placed on free versions. 

### Terms of use
As part of the [NEOS Server terms of use](http://www.neos-server.org/neos/termofuse.html), all models submitted to its solvers become part of the Public Domain.

## Installation
This package is not yet listed in `METADATA.jl`. To install it, run 

```julia
Pkg.clone("https://github.com/odow/NEOS.jl.git")
```

## The NEOS API
This package contains an interface for the NEOS XML-RPC [API](http://www.neos-server.org/neos/NEOS-API.html).

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
NEOSSolver(solver=:SOLVER, category=:CATEGORY)
```
where `:SOLVER` is one of `:CPLEX`, `:SYMPHONY`, `:XpressMP`. Currently, only the `:MILP` (Mixed Integer Linear Program) category is supported. The default solver is `:SYMPHONY`.

*Note*: both `:CPLEX` and `:XpressMP` require the user to supply a valid email address .
