a.out : lex.yy.c y.tab.c y.tab.h 
	gcc lex.yy.c y.tab.c -g -ll -lm

y.tab.c : project_yacc.y
	yacc -Wno-yacc -dv project_yacc.y

lex.yy.c : project_lex.l
	lex project_lex.l

clean :
	rm -rf lex.yy.c y.tab.c y.tab.h a.out y.output Tokens.txt TAC.txt Quads.txt SymbolTable.txt
