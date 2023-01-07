build:
	vim -Nu NONE -c 'helptags doc/' -c 'qa!'

test:
	bin/testrun
