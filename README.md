# NEOSServer.jl

[![Build Status](https://github.com/odow/NEOSServer.jl/workflows/CI/badge.svg?branch=master)](https://github.com/odow/NEOSServer.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/odow/NEOSServer.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/odow/NEOSServer.jl)

[NEOSServer.jl](https://github.com/odow/NEOSServer.jl) is a wrapper for the
[NEOS Server](http://www.neos-server.org/neos), a free internet-based
service for solving numerical optimization problems.

See [here](http://www.neos-server.org/neos/solvers/index.html) for the full
list of solvers and input formats that NEOS supports.

## Affiliation

This wrapper is maintained by the JuMP community and is not an official
interface of the NEOS Server.

## Getting help

If you need help, please ask a question on the [JuMP community forum](https://jump.dev/forum).

If you have a reproducible example of a bug, please [open a GitHub issue](https://github.com/odow/NEOSServer.jl/issues/new).

## License

`NEOSServer.jl` is licensed under the [MIT License](https://github.com/odow/NEOSServer.jl/blob/master/LICENSE.md).

Use of the [NEOS Server](http://www.neos-server.org/neos) requires you
to comply with [NEOS Server terms of use](http://www.neos-server.org/neos/termofuse.html).

In particular, the commercial solvers are to be used solely for academic,
non-commercial research purposes.

## Installation

Install NEOSServer.jl using the package manager:
```julia
import Pkg
Pkg.add("NEOSServer")
```

## The NEOS API

This package contains an interface for the [NEOS XML-RPC API](https://neos-server.org/neos/xml-rpc.html).

The following example shows how you can interact with the API. Wrapped XML-RPC
functions begin with `neos_` and are exported.

```julia
using NEOSServer

# Create a server. You must supply a valid email:
server = NEOSServer.Server("me@mydomain.com")

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

Use NEOSServer.jl with [JuMP](https://github.com/jump-dev/JuMP.jl) as follows:

```julia
using JuMP, NEOSServer
model = Model() do
    return NEOSServer.Optimizer(; email = "me@mydomain.com", solver = "Ipopt")
end
```

**Note: `NEOSServer.Optimizer` is limited to the following solvers:**

 * `"CPLEX"`
 * `"FICO-Xpress"`
 * `"Ipopt"`
 * `"Knitro"`
 * `"MOSEK"`
 * `"OCTERACT"`
 * `"SNOPT"`

## NEOS Limits

NEOS currently limits jobs to an 8 hour time limit, 3 GB of memory, and a 16 MB
submission file. If your model exceeds these limits, NEOSServer.jl may be unable
to return useful information to the user.
