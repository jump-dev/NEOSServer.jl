# NEOSServer.jl

[![Build Status](https://github.com/odow/NEOSServer.jl/workflows/CI/badge.svg?branch=master)](https://github.com/odow/NEOSServer.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/odow/NEOSServer.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/odow/NEOSServer.jl)

The [NEOS Server](http://www.neos-server.org/neos) is a free internet-based
service for solving numerical optimization problems. It is able to take models
specified in a variety of formats and pass them to a range of both free and 
commercial solvers. 

See [here](http://www.neos-server.org/neos/solvers/index.html) for the full 
list of solvers and input formats that NEOS supports.

NEOS is particularly useful if you need to trial a commercial solver to determine
if it meets your needs.

## Terms of use

As part of the [NEOS Server terms of use](http://www.neos-server.org/neos/termofuse.html),
the commercial solvers CPLEX, Gurobi, MOSEK, and FICO-Xpress are to be used solely for 
academic, non-commercial research purposes.

## Installation

Install NEOSServer.jl using the package manager:

```julia
import Pkg
Pkg.add("NEOSServer")
```

## The NEOS API

This package contains an interface for the [NEOS XML-RPC API](http://www.neos-server.org/neos/NEOS-API.html).

The following example shows how you can interact with the API. Wrapped XML-RPC
functions begin with `neos_` and are exported.

```julia
using NEOSServer

# Create a server. You must supply a valid email:
server = NEOSServer.Server(email="me@mydomain.com")

# Print the NEOS welcome message:
println(neos_welcome(server))

# Get an XML template:
xml_string = neos_getSolverTemplate(server, "milp", "Cbc", "AMPL")

# Modify template with problem data...

# Submit the XML job to NEOS:
job = neos_submitJob(server, xml_string)

# Get the status of the Job from NEOS:
status = neos_getJobStatus(server, job)

# Get the final results:
results = neos_getFinalResults(server, job)
```

## Use with JuMP

Use NEOSServer.jl with [JuMP](https://github.com/JuliaOpt/JuMP.jl) as follows:

```julia
using JuMP, NEOSSServer

model = Model() do 
    NEOSServer.Optimizer(email="me@mydomain.com", solver="Ipopt")
end
```

**Note: `NEOSServer.Optimizer` is limited to the following solvers: `"CPLEX"`,
`"FICO-Xpress"`, `"Gurobi"`, `"Ipopt"`, `"MOSEK"` and `"SNOPT"`.**

## NEOS Limits

NEOS currently limits jobs to an 8 hour timelimit, 3Gb of memory, and a 16mb
submission file. If your model exceeds these limits, NEOSServer.jl may be unable
to return useful information to the user.
