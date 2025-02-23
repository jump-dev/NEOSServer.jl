# Copyright (c) 2015: Oscar Dowson and NEOS.jl contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module NEOSServer

import AmplNLWriter
import Base64
import HTTP
import LightXML

function __init__()
    @warn(
        "Make sure you comply with the NEOS terms of use: " *
        "http://www.neos-server.org/neos/termofuse.html",
    )
    return
end

"""
    Server(email::String)

Construct a `Server` object. The `email` argument should take the users
valid email address (required for solvers like CPLEX).

## Example

```julia
julia> server = NEOSServer.Server("me@domain.com")
```
"""
struct Server
    user_agent::String
    host::String
    content_type::String
    email::String

    function Server(email::String)
        return new("NEOS.jl", "https://neos-server.org:3333", "text/xml", email)
    end
end

"""
    struct Job
        number::Int
        password::String
    end

Struct representing a NEOS job.
"""
struct Job
    number::Int
    password::String
end

# ==============================================================================
# 	NEOS API Methods
#
# Taken from https://neos-server.org/neos/xml-rpc.html
# ==============================================================================

_add_text(value, arg::String) = LightXML.add_text(value, arg)

function _add_text(value, arg)
    return LightXML.add_text(LightXML.new_child(value, "int"), string(arg))
end

function _build_xml(name::String, args...)
    xml = LightXML.XMLDocument()
    mthd = LightXML.create_root(xml, "methodCall")
    mname = LightXML.new_child(mthd, "methodName")
    LightXML.add_text(mname, name)
    if length(args) > 0
        params = LightXML.new_child(mthd, "params")
        for a in args
            param = LightXML.new_child(params, "param")
            value = LightXML.new_child(param, "value")
            _add_text(value, a)
        end
    end
    return string(xml)
end

function _get_values!(values, node)
    types = ["int", "i4", "string", "double", "base64", "dateTime.iso8601"]
    for child in LightXML.child_nodes(node)
        if LightXML.name(child) in types
            push!(values, LightXML.content(child))
        else
            _get_values!(values, child)
        end
    end
    return
end

function _api_method(s::Server, name::String, args...)
    xml = _build_xml(name, args...)
    headers = [
        "user-agent" => s.user_agent,
        "host" => s.host,
        "content-type" => s.content_type,
        "content-length" => string(length(xml)),
    ]
    res = HTTP.request("POST", s.host, headers, xml)
    if res.status != 200
        error("XML-RPC failed with code: $(res.status)")
    end
    parameters = Any[]
    xml = LightXML.parse_string(String(res.body))
    xroot = LightXML.root(xml)
    _get_values!(parameters, xroot)
    return parameters
end

function _decode_to_string(s)
    return String(Base64.base64decode(replace(s, "\n" => "")))
end

neos_help(s::Server) = only(_api_method(s, "help"))

neos_welcome(s::Server) = only(_api_method(s, "welcome"))

neos_version(s::Server) = only(_api_method(s, "version"))

neos_ping(s::Server) = only(_api_method(s, "ping"))

neos_printQueue(s::Server) = only(_api_method(s, "printQueue"))

function neos_getSolverTemplate(
    s::Server,
    category::String,
    solvername::String,
    inputMethod::String,
)
    ret = _api_method(s, "getSolverTemplate", category, solvername, inputMethod)
    return only(ret)
end

neos_listAllSolvers(s::Server) = _api_method(s, "listAllSolvers")

neos_listCategories(s::Server) = _api_method(s, "listCategories")

function neos_listSolversInCategory(s::Server, category::String)
    return _api_method(s, "listSolversInCategory", category)
end

function neos_submitJob(s::Server, xmlstring::String)
    res = _api_method(s, "submitJob", xmlstring)
    return Job(parse(Int, res[1]), res[2])
end

function neos_getJobStatus(s::Server, j::Job)
    return only(_api_method(s, "getJobStatus", j.number, j.password))
end

function neos_getCompletionCode(s::Server, j::Job)
    return only(_api_method(s, "getCompletionCode", j.number, j.password))
end

function neos_getJobInfo(s::Server, j::Job)
    return _api_method(s, "getJobInfo", j.number, j.password)
end

function neos_killJob(s::Server, j::Job)
    return _api_method(s, "killJob", j.number, j.password)
end

function neos_getFinalResults(s::Server, j::Job)
    ret = _api_method(s, "getFinalResults", j.number, j.password)
    return _decode_to_string(ret[1])
end

function neos_emailJobResults(s::Server, j::Job)
    return _api_method(s, "emailJobResults", j.number, j.password)
end

# neos_emailFinalResults was included in v1.x, but never tested, and it should
# hhave been neos_emailJobResults. I don't know when this changed in NEOS.
@deprecate neos_emailFinalResults neos_emailJobResults

function neos_getIntermediateResults(s::Server, j::Job, offset::Int)
    ret = _api_method(s, "getIntermediateResults", j.number, j.password, offset)
    return _decode_to_string(ret[1]), parse(Int, ret[2])
end

function neos_getFinalResultsNonBlocking(s::Server, j::Job)
    ret = _api_method(s, "getFinalResultsNonBlocking", j.number, j.password)
    return _decode_to_string(only(ret))
end

function neos_getIntermediateResultsNonBlocking(s::Server, j::Job, offset::Int)
    ret = _api_method(
        s,
        "getIntermediateResultsNonBlocking",
        j.number,
        j.password,
        offset,
    )
    return _decode_to_string(ret[1]), parse(Int, ret[2])
end

function neos_getOutputFile(s::Server, j::Job, fileName::String)
    ret = _api_method(s, "getOutputFile", j.number, j.password, fileName)
    return _decode_to_string(only(ret))
end

# ==============================================================================
# 	NEOS.Optimizer interface
# ==============================================================================

const _SUPPORTED_SOLVERS = Dict(
    "BARON" => "minco",
    "COPT" => "milp",
    "CPLEX" => "milp",
    "FICO-Xpress" => "milp",
    "Ipopt" => "nco",
    "Knitro" => "nco",
    "MOSEK" => "milp",
    "SNOPT" => "nco",
)

function Optimizer(; email::String, solver::String, kwargs...)
    category = get(_SUPPORTED_SOLVERS, solver, nothing)
    if category === nothing
        error(
            "NEOS.Optimizer only supports the following solvers: " *
            join(collect(keys(_SUPPORTED_SOLVERS)), ", "),
        )
    end
    cmd = _SolverCommand(solver, category, Server(email))
    return AmplNLWriter.Optimizer(cmd; kwargs...)
end

struct _SolverCommand <: AmplNLWriter.AbstractSolverCommand
    solver::String
    category::String
    server::Server
end

function AmplNLWriter.call_solver(
    solver::_SolverCommand,
    nl_filename::String,
    options::Vector{String},
    ::IO,
    stdout::IO,
)::String
    option_str = join([replace(o, "=" => " ") for o in options], "\n")
    xml = """
    <document>
    <client>NEOS.jl</client>
    <solver>$(solver.solver)</solver>
    <category>$(solver.category)</category>
    <inputMethod>NL</inputMethod>
    <email>![CDATA[$(solver.server.email)]]</email>
    <model>$(read(nl_filename, String))</model>
    <options><![CDATA[$option_str]]></options>
    </document>
    """
    job = neos_submitJob(solver.server, xml)
    polling_period = 1.0
    offset = 0
    while true
        ret, new_offset =
            neos_getIntermediateResultsNonBlocking(solver.server, job, offset)
        if new_offset > offset
            println(stdout, ret)
        end
        offset = new_offset
        if neos_getJobStatus(solver.server, job) == "Done"
            break
        end
        sleep(polling_period)
        polling_period = min(60.0, 2 * polling_period)
    end
    sol = neos_getOutputFile(solver.server, job, "ampl.sol")
    sol_file = replace(nl_filename, "model.nl" => "model.sol")
    write(sol_file, sol)
    return sol_file
end

# ==============================================================================
# 	Export NEOS API
# ==============================================================================

for sym in names(@__MODULE__; all = true)
    if startswith("$(sym)", "neos_")
        @eval export $sym
    end
end

end
