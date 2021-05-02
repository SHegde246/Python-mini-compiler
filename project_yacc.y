%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include <stdarg.h>

	#define MAX_ENTRIES 200
	#define MAX_ST 100
	
	extern int yylex();
	void yyerror(const char *s);
	
	extern FILE *yyin;
	extern int yylineno;
	extern int level;
	extern int top();
	extern int pop();
	int currentScope = 1;
	
	int *arrayScope = NULL;
	
	//structure of a single record in a symbol table
	typedef struct record
	{
		char *type;
		char *name;
		int lineno_declared;
		int lastUseLine;
	} record;

	//structure of a symbol table
	//there is one ST per scope
	typedef struct STable
	{
		int no;	//index
		int noOfElements;
		int scope;
		record *Elements;
		int Parent;	//gives position index of parent ST (in array of STs) 
		
	} STable;
	
	
	
	STable *symbolTables = NULL;
	int sIndex = -1;    //index of the ST
	
	
	/*-----------------------------Declarations----------------------------------*/
	
	void init();
	void initNewTable(int scope);
  	int power(int base, int exp);
  	void updateCScope(int scope);
  	void resetDepth();
	int scopeBasedTableSearch(int scope);
	int searchRecordInScope(const char* type, const char *name, int index);
	void modifyRecordID(const char *type, const char *name, int lineNo, int scope);
	void insertEntry(const char* type, const char *name, int lineNo, int scope);
	void checkIfList(const char *name, int lineNo, int scope);
	void printSymbolTables();
	void freeAll();
	
	/*------------------------------------------------------------------------------*/
	
	
	void init()
	{
		int i = 0;
		symbolTables = (STable*)calloc(MAX_ST, sizeof(STable));
		arrayScope = (int*)calloc(10, sizeof(int));
		initNewTable(1);
	}
	
	
	void initNewTable(int scope)
	{
		arrayScope[scope]++;
		sIndex++;
		symbolTables[sIndex].no = sIndex;
		symbolTables[sIndex].scope = power(scope, arrayScope[scope]);
		symbolTables[sIndex].noOfElements = 0;		
		symbolTables[sIndex].Elements = (record*)calloc(MAX_ENTRIES, sizeof(record));
		
		symbolTables[sIndex].Parent = scopeBasedTableSearch(currentScope); 
	}
	
	
	
	int power(int base, int exp)
	{
		int i =0, res = 1;
		for(i; i<exp; i++)
		{
			res *= base;
		}
		return res;
	}
	
	void updateCScope(int scope)
	{
		currentScope = scope;
	}
	
	void resetDepth()
	{
		while(top()) 
		{
			pop();
		}
		level = 10;
	}
	
	
	//search for a ST
	//ip = scope
	//op = index of the ST with that scope, if found, from array of STs
	int scopeBasedTableSearch(int scope)
	{
		int i = sIndex;
		for(i; i > -1; i--)
		{
			if(symbolTables[i].scope == scope)
			{
				return i;
			}
		}
		return -1;
	}
	
	

	//search for a record in a ST
	//ip = ST's index in array
	//op = index of record in ST, if found
	int searchRecordInScope(const char* type, const char *name, int index)
	{
		int i =0;
		for(i=0; i<symbolTables[index].noOfElements; i++)
		{
			if((strcmp(symbolTables[index].Elements[i].type, type)==0) && (strcmp(symbolTables[index].Elements[i].name, name)==0))
			{
				return i;
			}	
		}
		return -1;
	}
	
	
	//update an identifier's last used line, whenever it's encountered again
	/*It is a recursive function.
	If the identifier is not found in the ST of the current scope,
	it searches for it in the ST of the parent scope, recursively.
	Eventually, it reaches the base condition, where the scope becomes the root level scope, and there are no more parent scopes.
	If the identifier is not found even here, it means it's never been declared. Error gets thrown*/	
	void modifyRecordID(const char *type, const char *name, int lineNo, int scope)
	{
		int i =0;
		int index = scopeBasedTableSearch(scope);
		if(index==0)
		{
			for(i=0; i<symbolTables[index].noOfElements; i++)
			{
				
				if(strcmp(symbolTables[index].Elements[i].type, type)==0 && (strcmp(symbolTables[index].Elements[i].name, name)==0))
				{
					symbolTables[index].Elements[i].lastUseLine = lineNo;
					return;
				}	
			}
			printf("\nERROR: %s '%s' at line %d Not Declared\n", type, name, yylineno);
			exit(1);
		}
		
		for(i=0; i<symbolTables[index].noOfElements; i++)
		{
			if(strcmp(symbolTables[index].Elements[i].type, type)==0 && (strcmp(symbolTables[index].Elements[i].name, name)==0))
			{
				symbolTables[index].Elements[i].lastUseLine = lineNo;
				return;
			}	
		}
		return modifyRecordID(type, name, lineNo, symbolTables[symbolTables[index].Parent].scope);
	}
	
	
	
	//this is called whenever an identifier is encountered
	void insertEntry(const char* type, const char *name, int lineNo, int scope)
	{ 
		int FScope = power(scope, arrayScope[scope]);   //getting scope of identifier
		int index = scopeBasedTableSearch(FScope);      //finding appropriate ST, based on scope
		int recordIndex = searchRecordInScope(type, name, index);
		//if the identifier has never been seen before
		if(recordIndex==-1)
		{
			
			symbolTables[index].Elements[symbolTables[index].noOfElements].type = (char*)calloc(30, sizeof(char));
			symbolTables[index].Elements[symbolTables[index].noOfElements].name = (char*)calloc(20, sizeof(char));
			strcpy(symbolTables[index].Elements[symbolTables[index].noOfElements].type, type);	
			strcpy(symbolTables[index].Elements[symbolTables[index].noOfElements].name, name);
			
			symbolTables[index].Elements[symbolTables[index].noOfElements].lineno_declared = lineNo;
			symbolTables[index].Elements[symbolTables[index].noOfElements].lastUseLine = lineNo;
			symbolTables[index].noOfElements++;

		}
		//otherwise, it just updates the line of last use
		else
		{
			symbolTables[index].Elements[recordIndex].lastUseLine = lineNo;
		}
	}
	
	
	//checking to see if the identifier accessed is a list, by looking at the 'type' in the symbol table entry for that record
	//if type turns out to be anything other than list, error thrown, saying the identifier is not an iterable, and can't be indexed
	/*This is also a recursive function
	Works like modifyRecordID function*/	
	void checkIfList(const char *name, int lineNo, int scope)
	{
		int index = scopeBasedTableSearch(scope);
		int i;
		if(index==0)
		{
			
			for(i=0; i<symbolTables[index].noOfElements; i++)
			{
				
				if(strcmp(symbolTables[index].Elements[i].type, "ListIdentifier")==0 && (strcmp(symbolTables[index].Elements[i].name, name)==0))
				{
					symbolTables[index].Elements[i].lastUseLine = lineNo;
					return;
				}	

				else if(strcmp(symbolTables[index].Elements[i].name, name)==0)
				{
					printf("\nERROR: Identifier '%s' at line %d Not Indexable\n", name, yylineno);
					exit(1);

				}

			}
			printf("\nERROR: Identifier '%s' at line %d Not Indexable\n", name, yylineno);
			exit(1);
		}
		
		for(i=0; i<symbolTables[index].noOfElements; i++)
		{
			if(strcmp(symbolTables[index].Elements[i].type, "ListIdentifier")==0 && (strcmp(symbolTables[index].Elements[i].name, name)==0))
			{
				symbolTables[index].Elements[i].lastUseLine = lineNo;
				return;
			}
			
			else if(strcmp(symbolTables[index].Elements[i].name, name)==0)
			{
				printf("\nERROR: Identifier '%s' at line %d Not Indexable\n", name, yylineno);
				exit(1);

			}
		}
		
		return checkIfList(name, lineNo, symbolTables[symbolTables[index].Parent].scope);

	}
	
	//prints all the STs (from all the scopes)
	void printSymbolTables()
	{
		int i = 0, j = 0;
		
		printf("\n----------------------------Symbol Tables----------------------------");
		printf("\nScope\t\tName\t\tType\t\tDeclaration\t\tLast Used Line\n");
		for(i=0; i<=sIndex; i++)
		{
			for(j=0; j<symbolTables[i].noOfElements; j++)
			{
				printf("(%d, %d)\t\t%s\t\t%s\t\t%d\t\t%d\n", symbolTables[i].Parent, symbolTables[i].scope, symbolTables[i].Elements[j].name, symbolTables[i].Elements[j].type, symbolTables[i].Elements[j].lineno_declared,  symbolTables[i].Elements[j].lastUseLine);
			}
		}
		
		printf("-------------------------------------------------------------------------\n");
		
	}
	
	void freeAll()
	{
		int i = 0, j = 0;
		for(i=0; i<=sIndex; i++)
		{
			for(j=0; j<symbolTables[i].noOfElements; j++)
			{
				free(symbolTables[i].Elements[j].name);
				free(symbolTables[i].Elements[j].type);	
			}
			free(symbolTables[i].Elements);
		}
		free(symbolTables);
	}
%}

%union { char *text; int level;};

//needed for line numbers (@n.first_line)
%locations
   	  
%token T_Import T_Print T_If T_Elif T_Else T_For T_Def T_Pass T_Break T_Return T_Range
%token T_INDENT T_DEDENT
%token T_In T_Not T_And T_Or
%token T_GT T_LT T_GE T_LE T_EQ T_NE
%token T_True T_False
%token T_Plus T_Minus T_Mult T_Div
%token T_OP T_CP T_OSB T_CSB
%token T_Comma T_Colon T_Assign
%token T_String T_Number T_ID
%token T_EndOfFile

%token T_NL
%token T_ND


%right T_Assign
%left T_And T_Or
%left T_LT T_GT T_LE T_GE T_EQ T_NE
%left T_Plus T_Minus
%left T_Mult T_Div


%nonassoc T_If
%nonassoc T_Elif
%nonassoc T_Else

//tells parser to expect exactly two conflicts
%expect 2


%start StartDebugger

%%

StartDebugger : {init();} StartParse T_EndOfFile {printf("\n\nValid Python Syntax\n------------");  printSymbolTables(); freeAll(); exit(0);} ;

StartParse : T_NL StartParse | finalStatements T_NL {resetDepth();} StartParse | finalStatements | ;


constant : T_Number {insertEntry("Constant", $<text>1, @1.first_line, currentScope); }
         | T_String {insertEntry("Constant", $<text>1, @1.first_line, currentScope); };

term : T_ID {modifyRecordID("Identifier", $<text>1, @1.first_line, currentScope); } 
     | constant 
     | list_index ;


list_index : T_ID T_OSB T_Number T_CSB {checkIfList($<text>1, @1.first_line, currentScope); };


basic_stmt : pass_stmt
           | break_stmt
           | import_stmt
           | assign_stmt
           | arith_exp
           | bool_exp
           | print_stmt
           | return_stmt;
           
pass_stmt : T_Pass ;

break_stmt : T_Break ;

import_stmt : T_Import T_ID {insertEntry("ModuleName", $<text>2, @2.first_line, currentScope); };

assign_stmt : T_ID T_Assign arith_exp {insertEntry("Identifier", $<text>1, @1.first_line, currentScope); }  
            | T_ID T_Assign bool_exp {insertEntry("Identifier", $<text>1, @1.first_line, currentScope); }   
            | T_ID  T_Assign func_call {insertEntry("Identifier", $<text>1, @1.first_line, currentScope); } 
            | T_ID T_Assign T_OSB call_args T_CSB {insertEntry("ListIdentifier", $<text>1, @1.first_line, currentScope); } ;

arith_exp : term
          | arith_exp  T_Plus  arith_exp
          | arith_exp  T_Minus  arith_exp
          | arith_exp  T_Mult  arith_exp
          | arith_exp  T_Div  arith_exp
          | T_Minus arith_exp
          | T_OP arith_exp T_CP ;
		    

bool_exp : bool_term T_Or bool_term 
         | bool_term T_And bool_term           
         | arith_exp T_EQ arith_exp
         | arith_exp T_GT arith_exp
         | arith_exp T_LT arith_exp 
         | arith_exp T_GE arith_exp
         | arith_exp T_LE arith_exp
         | arith_exp T_NE arith_exp
         | arith_exp T_In T_ID {checkIfList($<text>3, @3.first_line, currentScope);}
         | bool_term ; 

bool_term : bool_factor  
          | T_True {insertEntry("Constant", "True", @1.first_line, currentScope); }
          | T_False {insertEntry("Constant", "False", @1.first_line, currentScope); }; 
          
bool_factor : T_Not bool_factor 
            | T_OP bool_exp T_CP; 
            

print_stmt : T_Print T_OP call_args T_CP ;


return_stmt : T_Return ;

	     

finalStatements : basic_stmt 
                | cmpd_stmt 
                | func_def 
                | func_call 
                | error T_NL {yyerrok; yyclearin; }; //yyerrok is a mechanism that can force the parser to believe that error recovery has been accomplished. 
							//The statement: yyerrok ; in an action resets the parser to its normal mode.
							/*After an Error action, the parser restores the lookahead symbol to the value it had at the time the error was detected. 
							However, this is sometimes undesirable.
							If you want the parser to throw away the old lookahead symbol after an error, use yyclearin*/

cmpd_stmt : if_stmt 
          | for_stmt ;





//this will provide 2 shift/reduce conflicts. One for elif, one for else.
/*this can be ignored as the default action of yacc in a s/r conflict is to shift
, (so that the elif/else if associated with the closer if) which is what we need*/
if_stmt : T_If bool_exp T_Colon start_block	
        | T_If bool_exp T_Colon start_block elif_stmts ;
        
elif_stmts : else_stmt 
           | T_Elif bool_exp T_Colon start_block elif_stmts ;
           
else_stmt : T_Else T_Colon start_block ;





iterable: T_ID {checkIfList($<text>1, @1.first_line, currentScope);}
	| T_Range T_OP T_Number T_Comma T_Number T_CP ;

for_stmt : T_For T_ID T_In iterable T_Colon start_block {insertEntry("Identifier", $<text>2, @2.first_line, currentScope); };





start_block : basic_stmt 
            | T_NL T_INDENT {initNewTable($<level>2); updateCScope($<level>2);} finalStatements block ;

block : T_NL T_ND finalStatements block 
      | T_NL end_block ;

end_block : T_DEDENT {updateCScope($<level>1);} finalStatements 
          | T_DEDENT {updateCScope($<level>1);}
          | {resetDepth();};

args : T_ID args_list
     | ;

args_list : T_Comma T_ID args_list | ;


call_list : T_Comma term call_list | ;

call_args : T_ID call_list
	| T_Number call_list
	| T_String call_list	
	| ;

func_def : T_Def T_ID {insertEntry("Func_Name", $<text>2, @2.first_line, currentScope);} T_OP args T_CP T_Colon start_block ;

func_call : T_ID T_OP call_args T_CP ;

 
%%

void yyerror(const char *msg)
{
	printf("\nSyntax Error at Line %d, Column : %d\n",  yylineno, yylloc.last_column);
	exit(0);
}

int main(int argc, char *argv[])
{
	yyin = fopen(argv[1], "r");
	yyparse();
	return 0;
}

