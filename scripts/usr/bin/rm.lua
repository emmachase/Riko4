--HELP: \b6Usage: \b16rm \b7<\b16file\b7> \n
-- \b6Description: \b7Deletes \b16file

local arg = ({...})[1]

fs.delete(arg)