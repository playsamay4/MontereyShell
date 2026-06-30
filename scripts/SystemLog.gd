extends Node


func log(p1=null, p2=null, p3=null, p4=null, p5=null, p6=null):
	var time = Time.get_time_string_from_system()
	var raw_parts = [p1, p2, p3, p4, p5, p6]
	
	var args = []
	for p in raw_parts:
		if p != null: args.append(p)
		
	if args.size() == 0:
		return

	var final_message = ""
	
	if args[0] is String and "%" in args[0] and args.size() > 1:
		var format_str = args[0]
		var format_values = args.slice(1) 
		
		if format_values.size() == 1:
			final_message = format_str % format_values[0]
		else:
			final_message = format_str % [format_values]
	else:
		var string_parts = []
		for arg in args:
			string_parts.append(str(arg))
		final_message = " ".join(string_parts)
		
	print("[%s] %s" % [time, final_message])
