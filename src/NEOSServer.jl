type NEOSServer
	useragent::ASCIIString
	host::ASCIIString
	contenttype::ASCIIString
	email::ASCIIString
	NEOSServer(;email="") = new("JuliaXMLRPC", "http://neos-server.org:3332", "text/xml", email)
end

function addemail!(s::NEOSServer, email::ASCIIString)
	s.email = email
end

type NEOSJob
	number::Int64
	password::ASCIIString
end

function _method(s::NEOSServer, name::ASCIIString, args...)
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
				myint = new_child(value, "int")
				add_text(myint, string(a))
			end
		end
	end
	return _send(s, string(xml))
end

function _send(s::NEOSServer, xml::ASCIIString)
	hdrs = Dict{AbstractString, AbstractString}("user-agent" => s.useragent, "host" => s.host,
	"content-type" => s.contenttype, "content-length" => string(length(xml)))
	res = post(s.host; headers=hdrs, data=xml)
	if res.status == 200
		return extractResponse(res.data)
	else
		error("XML-RPC failed. Response is $res")
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

function extractResponse(s)
	parameters = Array(Any, 0)
	xml = parse_string(convert(ASCIIString, s))
	xroot = root(xml)
	getValues!(parameters, xroot)
	return parameters
end

# ===========================================
#
# 	NEOS API Methods
#
function neosHelp(s::NEOSServer)
	return _method(s, "help")[1]
end

messages = [:emailHelp, :welcome, :version, :ping, :printQueue]
for m in messages
	m_str = string(m)
	@eval 	function ($m)(s::NEOSServer)
				return _method(s, $(m_str))[1]
			end
end

lists = [:listAllSolvers, :listCategories]
for m in lists
	m_str = string(m)
	@eval 	function ($m)(s::NEOSServer)
				return _method(s, $(m_str))
			end
end

function getSolverTemplate(s::NEOSServer, category::Symbol, solvername::Symbol, inputMethod::Symbol)
	_method(s, "getSolverTemplate", string(category), string(solvername), string(inputMethod))[1]
end

function listSolversInCategory(s::NEOSServer, category::Symbol)
	_method(s, "listSolversInCategory", string(category))
end

function submitJob(s::NEOSServer, xmlstring::ASCIIString)
	res = _method(s, "submitJob", xmlstring)
	println("===================")
	println("NEOS Job submitted")
	println("number:\t$(res[1])")
	println("pwd:\t$(res[2])")
	println("==================")
	return NEOSJob(parse(Int, res[1]), res[2])
end

job_methods = [:getJobStatus, :killJob]
for m in job_methods
	m_str = string(m)
	@eval 	function ($m)(s::NEOSServer, j::NEOSJob)
				return _method(s, $(m_str), j.number, j.password)[1]
			end
end

function getJobInfo(s::NEOSServer, j::NEOSJob)
	_method(s, "getJobInfo", j.number, j.password)
end


for s in ["", "NonBlocking"]
	_final_str = "getFinalResults$s"
	_final = symbol(_final_str)
	_intermediate_str = "getIntermediateResults$s"
	_intermediate = symbol(_intermediate_str)
	@eval function ($_final)(s::NEOSServer, j::NEOSJob)
		decode_to_string(_method(s, $(_final_str), j.number, j.password)[1])
	end

	@eval function ($(_intermediate))(s::NEOSServer, j::NEOSJob; offset=0)
		decode_to_string(_method(s, $(_intermediate_str), j.number, j.password, offset)[1])
	end
end

function decode_to_string(s)
	bytestring(decode(Base64, replace(s, "\n", "")))
end
