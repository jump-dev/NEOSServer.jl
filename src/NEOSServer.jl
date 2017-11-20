type NEOSServer
	useragent::String
	host::String
	contenttype::String
	email::String
	NEOSServer(;email="") = new("JuliaXMLRPC", "https://neos-server.org:3333", "text/xml", email)
end

function addemail!(s::NEOSServer, email::String)
	s.email = email
end

type NEOSJob
	number::Int64
	password::String
end

_add_text(value, arg::String) = add_text(value, arg)
_add_text(value, arg) = add_text(new_child(value, "int"), string(arg))

function buildxml(s::NEOSServer, name::String, args...)
	xml = XMLDocument()
	mthd = 	create_root(xml, "methodCall")
	mname = new_child(mthd, "methodName")
	add_text(mname, name)
	if length(args) > 0
		params = new_child(mthd, "params")
		for a in args
			param = new_child(params, "param")
			value = new_child(param, "value")
			_add_text(value, a)
		end
	end
	return string(xml)
end

function apimethod(s::NEOSServer, name::String, args...)
	xml = buildxml(s, name, args...)
	res = send(s, xml)
	parseresponse(res)
end
function send(s::NEOSServer, xml::String)
	hdrs = Dict{String, String}("user-agent" => s.useragent, "host" => s.host,
	"content-type" => s.contenttype, "content-length" => string(length(xml)))
	res = post(s.host; headers=hdrs, data=xml)
end

function getvalues!(values, node)
	types = ["int", "i4", "string", "double", "base64", "dateTime.iso8601"]
	for child in child_nodes(node)
		if name(child) in types
			push!(values, content(child))
		else
			getvalues!(values, child)
		end
	end
end

function parseresponse(res)
	if res.status != 200
		error("XML-RPC failed with code: $(res.status)")
	end
	parameters = Any[]
	xml = parse_string(convert(String, res.data))

	xroot = root(xml)
	getvalues!(parameters, xroot)
	return parameters
end

# ===========================================
#
# 	NEOS API Methods
#
function neosHelp(s::NEOSServer)
	return apimethod(s, "help")[1]
end

messages = [:emailHelp, :welcome, :version, :ping, :printQueue]
for m in messages
	m_str = string(m)
	@eval 	function ($m)(s::NEOSServer)
				return apimethod(s, $(m_str))[1]
			end
end

lists = [:listAllSolvers, :listCategories]
for m in lists
	m_str = string(m)
	@eval 	function ($m)(s::NEOSServer)
				return apimethod(s, $(m_str))
			end
end

function getSolverTemplate(s::NEOSServer, category::String, solvername::String, inputMethod::String)
	apimethod(s, "getSolverTemplate", category, solvername, inputMethod)[1]
end

function listSolversInCategory(s::NEOSServer, category::String)
	apimethod(s, "listSolversInCategory", category)
end

function submitJob(s::NEOSServer, xmlstring::String)
	res = apimethod(s, "submitJob", xmlstring)
	println("===================")
	println("NEOS Job submitted")
	println("number:\t$(res[1])")
	println("pwd:\t$(res[2])")
	println("==================")
	return NEOSJob(parse(Int, res[1]), res[2])
end

jobapimethods = [:getJobStatus, :killJob]
for m in jobapimethods
	m_str = string(m)
	@eval 	function ($m)(s::NEOSServer, j::NEOSJob)
				return apimethod(s, $(m_str), j.number, j.password)[1]
			end
end

function getJobInfo(s::NEOSServer, j::NEOSJob)
	apimethod(s, "getJobInfo", j.number, j.password)
end


for s in ["", "NonBlocking"]
	_final_str = "getFinalResults$s"
	_final = Symbol(_final_str)
	_intermediate_str = "getIntermediateResults$s"
	_intermediate = Symbol(_intermediate_str)
	@eval function ($_final)(s::NEOSServer, j::NEOSJob)
		decode_to_string(apimethod(s, $(_final_str), j.number, j.password)[1])
	end

	@eval function ($(_intermediate))(s::NEOSServer, j::NEOSJob; offset=0)
		decode_to_string(apimethod(s, $(_intermediate_str), j.number, j.password, offset)[1])
	end
end


function decode_to_string(s)
	String(decode(Base64, replace(s, "\n", "")))
end
