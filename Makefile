# generate SECTR2.DO from TPDD2_sector.bas
# treat TPDD2_sector.bas as source and SECTR2.DO as executable

# Requires github.com/bkw777/BA_stuff
# "make install" requires github.com/bkw777/dlplus
# On Windows you can use github.com/bkw777/tsend in place of "make install"

SRC=TPDD2_sector.bas
OBJ=SECTR2.DO

all: $(OBJ)

$(OBJ): $(SRC)
	bapack <$(SRC) |START=0 STEP=1 barenum >$(@)

PHONY: renum
renum: $(SRC)
	cp -f $(SRC) $(SRC).bak
	SPACE=true barenum <$(SRC).bak >$(SRC)
	rm -f $(SRC).bak

PHONY: install
install: $(OBJ)
	@echo "What tty device is the portable connected to?"
	@echo "Press Enter for the default ttyUSB0, otherwise enter a name like ttyS0, ttyUSB1, etc."
	@read -p ": " d && dl $${d} -b=./$(OBJ)

PHONY: clean
clean:
	rm -f $(SRC).bak $(OBJ)
