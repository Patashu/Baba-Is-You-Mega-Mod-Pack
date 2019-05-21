
import os
import difflib

header = """
-- GENERATED FILE, DO NOT EDIT (or do, I'm not your mom)
return function (mod)
	mod.onLoad(function (dir)
"""

middle = """
	end)
	mod.onUnload(function (dir)
"""

footer = """
	end)
end
"""

if __name__ == "__main__":
	ignore = ["load.lua"]
	changed = []

	for file in os.listdir("replacements"):
		if file.endswith(".lua") and file not in ignore:
			lines = open("replacements/" + file, "r").readlines()
			vanilla_lines = open("../../../" + file, "r").readlines()
			diff = list(difflib.unified_diff(vanilla_lines, lines, fromfile="vanilla" + file, tofile="modded"))
			if len(diff) > 0:
				changed.append(file[:-4])
				print "%s changed (%d diff lines)" % (file, len(diff))

	print "\n\nWriting replacements.lua"
	with open("replacements.lua", "w") as out:
		out.write(header)
		for file in changed:
			out.write("\t\tloadscript(dir .. \"replacements/%s\")\n" % file)
		out.write(middle)
		for file in changed:
			out.write("\t\tloadscript(\"Data/%s\")\n" % file)
		out.write(footer)