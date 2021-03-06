REBAR = $(shell pwd)/rebar

.PHONY: deps rel stagedevrel version all

all: deps compile

version:
	echo "$(shell git symbolic-ref HEAD 2> /dev/null | cut -b 12-)-$(shell git log --pretty=format:'%h, %ad' -1)" > snarl.version

version_header: version
	echo "-define(VERSION, <<\"$(shell cat snarl.version)\">>)." > apps/snarl/src/snarl_version.hrl

compile: version_header
	$(REBAR) compile

deps:
	$(REBAR) get-deps

clean:
	$(REBAR) clean
	make -C rel/pkg clean

distclean: clean devclean relclean
	$(REBAR) delete-deps

test: all
	$(REBAR) skip_deps=true xref
	$(REBAR) skip_deps=true eunit

rel: all zabbix
	$(REBAR) generate

relclean:
	rm -rf rel/snarl

devrel: dev1 dev2 dev3 dev4

package: rel
	make -C rel/pkg package

zabbix:
	sh generate_zabbix_template.sh

###
### Docs
###
docs:
	$(REBAR) skip_deps=true doc

##
## Developer targets
##

stage : rel
	$(foreach dep,$(wildcard deps/* wildcard apps/*), rm -rf rel/snarl/lib/$(shell basename $(dep))-* && ln -sf $(abspath $(dep)) rel/snarl/lib;)


stagedevrel: dev1 dev2 dev3 dev4
	mkdir -p dev/dev{1,2,3}/data/{users,groups,ring}
	$(foreach dev,$^,\
	  $(foreach dep,$(wildcard deps/* wildcard apps/*), rm -rf dev/$(dev)/lib/$(shell basename $(dep))-* && ln -sf $(abspath $(dep)) dev/$(dev)/lib;))

devrel: dev1 dev2 dev3 dev4


devclean:
	rm -rf dev

dev1 dev2 dev3 dev4: all
	mkdir -p dev
	(cd rel && $(REBAR) generate target_dir=../dev/$@ overlay_vars=vars/$@.config)


##
## Dialyzer
##
APPS = kernel stdlib sasl erts ssl tools os_mon runtime_tools crypto inets \
	xmerl webtool snmp public_key mnesia eunit syntax_tools compiler
COMBO_PLT = $(HOME)/.snarl_combo_dialyzer_plt

check_plt: deps compile
	dialyzer --check_plt --plt $(COMBO_PLT) --apps $(APPS) \
		deps/*/ebin apps/*/ebin

build_plt: deps compile
	dialyzer --build_plt --output_plt $(COMBO_PLT) --apps $(APPS) \
		deps/*/ebin apps/*/ebin

dialyzer: deps compile
	@echo
	@echo Use "'make check_plt'" to check PLT prior to using this target.
	@echo Use "'make build_plt'" to build PLT prior to using this target.
	@echo
	@sleep 1
	dialyzer -Wno_return --plt $(COMBO_PLT) deps/*/ebin apps/*/ebin | grep -v -f dialyzer.mittigate


cleanplt:
	@echo
	@echo "Are you sure?  It takes about 1/2 hour to re-build."
	@echo Deleting $(COMBO_PLT) in 5 seconds.
	@echo
	sleep 5
	rm $(COMBO_PLT)
