.SUFFIXES: .erl .beam .yrl

.erl.beam:
	erlc -W $<

MODS =  chat_client chat_group chat_server\
	io_widget \
	lib_chan lib_chan_mm lib_chan_cs\
        lib_chan_auth lib_md5\
        mod_echo mod_math mod_chat_controller mod_name_server


ERL = erl -boot start_clean 

all:	compile
	
compile: ${MODS:%=%.beam}
	mkdir -p ${HOME}/.erlang_config/
	cp conf ${HOME}/.erlang_config/lib_chan.conf
	@echo "make clean - clean up"

chat_client: compile
	erl -pa ../ -s chat_client test

chat_server: compile
	erl -pa ../ -s chat_server start

clean:	
	rm -rf *.beam erl_crash.dump
