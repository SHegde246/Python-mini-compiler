%{
#include<stdio.h>
#include<string.h>
#include<stdlib.h>

//yyparse from yacc file generates the y.tab.c file, which contains the parser,
//it also creates a header file, y.tab.h, which can be included in the lex file,
//from which it can access the tokens defined in the yacc file
#include "y.tab.h"

#define STACK_LIMIT 100

#define START 1


//YY_USER_ACTION macro is a default action for locations, that is run each time a pattern is matched (it is inserted at the beginning of each action)
//assumes the tokens in each rule span only one line. Hence, first and last lines are the same
//sets the beginning of column location LHS of each production rule (@$) to the beginning of the first symbol on RHS, and the end of @$ to the end of the last symbol
#define YY_USER_ACTION yylloc.first_line = yylloc.last_line = yylineno; 		\
    yylloc.first_column = yycolumn; yylloc.last_column = yycolumn + yyleng - 1; 	\
    yycolumn += yyleng;	

int flag = 1;
int yycolumn = 1;

FILE* ftokens=NULL;


//stack to handle indent/dedent
static int sp=0, stack[STACK_LIMIT];


static void push (int i) 
{
	if (++sp<STACK_LIMIT) 
	{
		stack[sp]= i;
	}
	else 
	{	printf ("error: stack overflow\n"); 
		exit(1);
	}
}

int pop () 
{
	if (sp>-1) 
	{
		return stack[sp--];
	}
	else 
	{	printf ("error: stack underflow\n"); 
		exit(1);
	}
}

int top()
{
	if(sp>-1) 
	{
		return stack[sp];
	}
	else 
	{
		return 1;
	}
}


static void printToken(const char *X)
 	{
 		#ifdef START
 		if(!ftokens)
			ftokens=fopen("Tokens.txt","w");
 		
 		
 		if(flag)
 		{
 			fprintf(ftokens,"\n---------------------------------------------------------------Tokens-----------------------------------------------------------------\n  1 ");
 			printf("---------------------------------Tokens--------------------------\n1 ");
 			flag=0;
 		}
 		
 		if(strcmp(X, "NL")==0)
 		{
 			fprintf(ftokens,"T_%s\n%s%d ", X, "  ", yylineno);
 			printf("T_%s\n%d ", X, yylineno);
 		}
		else
		{
			fprintf(ftokens,"T_%s ", X);
			printf("T_%s ", X);	
		}
 		#endif
 	}




//function which calculates the level of indentation
//to be used while generating indent and dedent tokens
int indentation_level(const char *lexeme)
{
	int length=strlen(lexeme);
	int tab_level=0; 
	for(int i=0; i<length; ++i)
	{
		if(lexeme[i]=='\t')
		{
			tab_level++;
		}
	}
	return tab_level;
}


int level=0;


%}

number [0-9]+
identifier [_a-zA-Z][_a-zA-Z0-9]*
dq_string \"([^\"\n])*\"
sq_string '([^'\n])*'

%option noyywrap
%option yylineno

%x ml_comment_dq ml_comment_sq 

%%
[\t]*	{
		level=indentation_level(yytext);
		printf("level is %d\n", level);
		
		if(level==top())
		{
			printToken("ND");
			yylval.level = level;
			return T_ND;
		}
		else if(level>top())
		{
			push(level);
			//printf("<INDENT>");
			printToken("INDENT");
			yylval.level = level;
			return T_INDENT;
		}
		else if(level < top())
		{
			while(level < top())
			{
				pop();
				//printf("<DEDENT>");
			}
			yylval.level = level;
			printToken("DEDENT");
			return T_DEDENT;
		}
	}

\"\"\"	{BEGIN(ml_comment_dq);}
<ml_comment_dq>[\n]	{}	
<ml_comment_dq>[^\"]*	{}
<ml_comment_dq>\"\"\"	BEGIN(INITIAL);

'''	{BEGIN(ml_comment_sq);}
<ml_comment_sq>[\n]	{}	
<ml_comment_sq>[^']*	{}
<ml_comment_sq>'''	BEGIN(INITIAL);

"#".*	{}

[ ]	{}





import {printToken("Import"); return T_Import;}
def	{printToken("Def"); return T_Def;}



print	{printToken("Print"); return T_Print;}
pass	{printToken("Pass"); return T_Pass;}
if	{printToken("If"); return T_If;}
elif	{printToken("Elif"); return T_Elif;}
else	{printToken("Else"); return T_Else;}
in	{printToken("In"); return T_In;}
for	{printToken("For"); return T_For;}
break	{printToken("Break"); return T_Break;}
not	{printToken("Not"); return T_Not;}
and	{printToken("And"); return T_And;}
or	{printToken("Or"); return T_Or;}
return	{printToken("Return"); return T_Return;}
range	{printToken("Range"); return T_Range;}


">"	{printToken("GT"); return T_GT;}
"<"	{printToken("LT"); return T_LT;}
">="	{printToken("GE"); return T_GE;}
"<="	{printToken("LE"); return T_LE;}
"=="	{printToken("EQ"); return T_EQ;}
"!="	{printToken("NE"); return T_NE;}

"True"	{printToken("True"); return T_True;}
"False"	{printToken("False"); return T_False;}


"+"	{printToken("Plus"); return T_Plus;}
"-"	{printToken("Minus"); return T_Minus;}
"*"	{printToken("Mult"); return T_Mult;}
"/"	{printToken("Div"); return T_Div;}
"("	{printToken("OP"); return T_OP;}
")"	{printToken("CP"); return T_CP;}
"["	{printToken("OSB"); return T_OSB;}
"]"	{printToken("CSB"); return T_CSB;}
","	{printToken("Comma"); return T_Comma;}
":"	{printToken("Colon"); return T_Colon;}
"="	{printToken("Assign"); return T_Assign;}
{dq_string}	{yylval.text = strdup(yytext); printToken(yylval.text); return T_String;}
{sq_string}	{yylval.text = strdup(yytext); printToken(yylval.text); return T_String;}
{number}	{yylval.text = strdup(yytext); printToken(yylval.text); return T_Number;}
{identifier}	{yylval.text = strdup(yytext); printToken(yylval.text); return T_ID;}


<<EOF>>	{	
			printToken("EOF"); 
			return T_EndOfFile;
		}
\n	{printToken("NL"); yycolumn=1; return T_NL;}	
		

%%



