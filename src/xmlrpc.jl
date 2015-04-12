type Server
	useragent::String
	host::String
	contenttype::String
	Server(host, port) = new("JuliaXMLRPC", "http://$(host):$(port)", "text/xml")
end

function method(s::Server, name::ASCIIString, args...)
	xml = XMLDocument()

	mthd = 	create_root(xml, "methodCall")
	mname = new_child(mthd, "methodName")
	add_text(mname, name)

	if length(args) > 0
		params = new_child(mthd, "params")
		for a in args
			param = new_child(params, "param")
			value = new_child(param, "value")
			if isa(a, ASCIIString)
				add_text(value, a)
			else
				int = new_child(value, "int")
				add_text(int, string(a))
			end
		end
		
	end
	return send(s, string(xml))
end

function send(s::Server, xml::ASCIIString)
	hdrs = Dict{String, String}(["user-agent" => s.useragent, "host" => s.host, 
	"content-type" => s.contenttype, "content-length" => string(length(xml))])
	res = post(s.host; headers=hdrs, data=xml)
	if res.status == 200
		return extractResponse(res.data)
	else
		error("XML-RPC failed")
	end
end

function getValues!(values, c)
	types = ["int", "i4", "string", "double", "base64", "dateTime.iso8601"]
	for d in child_nodes(c)
		if name(d) in types
			push!(values, content(d))
		else
			getValues!(values, d)
		end
	end
end

function extractResponse(s::ASCIIString)
	parameters = Array(Any, 0)
	xml = parse_string(s)
	xroot = root(xml)
	getValues!(parameters, xroot)
	return parameters
end

# ===========================================
#
# 	NEOS API Methods
#
function neosHelp(s::NEOSSolver)
	return method(s.server, "help")[1]
end

messages = [:emailHelp, :welcome, :version, :ping, :printQueue]
for m in messages
	@eval 	function ($m)(s::NEOSSolver)
				return method(s.server, string($m))[1]
			end
end

lists = [:listAllSolvers, :listCategories]
for m in lists
	@eval 	function ($m)(s::NEOSSolver)
				return method(s.server, string($m))
			end
end

function getSolverTemplate(s::NEOSSolver, category::Symbol, solvername::Symbol, inputMethod::Symbol)
	method(s.server, "getSolverTemplate", string(category), string(solvername), string(inputMethod))[1]
end

function listSolversInCategory(s::NEOSSolver, category::Symbol)
	method(s.server, "listSolversInCategory", string(category))
end

function submitJob(s::NEOSSolver, xmlstring::ASCIIString)
	res = method(s.server, "submitJob", xmlstring)
	println("===================")
	println("NEOS Job submitted")
	println("number:\t$(res[1])")
	println("pwd:\t$(res[2])")
	println("==================")
	return Job(parseint(res[1]), res[2])
end

job_methods = [:getJobStatus, :killJob, :getFinalResults, :getFinalResultsNonBlocking]
for m in job_methods
	@eval 	function ($m)(s::NEOSSolver, j::Job)
				return method(s.server, string($m), j.number, j.password)
			end
end

function getJobInfo(s::NEOSSolver, j::Job)
	method(s.server, "getJobInfo", j.number, j.password)
end

function getIntermediateResults(s::NEOSSolver, j::Job; offset=0)
	method(s.server, "getIntermediateResults", j.number, j.password, offset)
end

function getIntermediateResultsNonBlocking(s::NEOSSolver, j::Job; offset=0)
	method(s.server, "getIntermediateResultsNonBlocking", j.number, j.password, offset)
end
