%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include <stdarg.h>

	#include <math.h>
	
	#define MAX_ENTRIES 200  //(in ST)
	
	#define MAX_ST 100
	
	extern int yylex();
	void yyerror(const char *s);
	
	extern FILE *yyin;
	extern int yylineno;
	extern int level;
	extern int top();
	extern int pop();
	
	//changed int currentScope = 1;
	int currentScope = 0;
	
	
	int scopeChange = 0; //flag
	
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
		//changed int no;	//index
		int no;
		
		int noOfElements;
		int STscope;
		record *Elements;
		int Parent;	//gives position index of parent ST (in array of STs) 
		
	} STable;
	
	
	
	STable *symbolTables = NULL;  //array of stuctures
	int sIndex = -1;    //index of the ST
	
	
	/*-----------------------------Declarations----------------------------------*/
	
	void init();
	void initNewTable(int scope);
  	//int power(int base, int exp);
  	void updateCScope(int scope);
  	void resetDepth();
	int scopeBasedTableSearch(int scope);
	int searchRecordInScope(const char* type, const char *name, int index);
	void modifyRecordID(const char *type, const char *name, int lineNo, int scope);
	void insertEntry(const char* type, const char *name, int lineNo, int scope);
	void checkIfList(const char *name, int lineNo, int scope);
	void printSymbolTables();
	void freeAll();
	
	int hashScope(int codeScope);
	
	/*------------------------------------------------------------------------------*/
	
	
	void init()
	{
		int i = 0;
		symbolTables = (STable*)calloc(MAX_ST, sizeof(STable));
		arrayScope = (int*)calloc(10, sizeof(int));
		
		//changed initNewTable(1);
		initNewTable(++currentScope);
	}
	
	
	void initNewTable(int scope)
	{
		arrayScope[scope]++;
		sIndex++;
		symbolTables[sIndex].no = sIndex;
		
		//changed symbolTables[sIndex].STscope = power(scope, arrayScope[scope]);
		//added
		symbolTables[sIndex].STscope = hashScope(scope);
		
		symbolTables[sIndex].noOfElements = 0;		
		symbolTables[sIndex].Elements = (record*)calloc(MAX_ENTRIES, sizeof(record));
		
		//changed symbolTables[sIndex].Parent = scopeBasedTableSearch(currentScope); 
		//added
		symbolTables[sIndex].Parent = scopeBasedTableSearch(scope - 1);
	}
	
	
	
	int hashScope(int codeScope)
	{
		return pow(codeScope, arrayScope[codeScope] + 1);
	}
	
	/* changed
	int power(int base, int exp)
	{
		int i =0, res = 1;
		for(i; i<exp; i++)
		{
			res *= base;
		}
		return res;
	}
	*/
	
	
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
			if(symbolTables[i].STscope == scope)
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
	//this is called whenever an identifier is encountered in a non-assignment stmt or in the RHS of an assignment stmt
	//(when identifier not LHS of assignment stmt)
	/*ex-
	a==7
	b=a+4
	a<=9
	etc
	*/
	//Here, the only information about the identifier that needs to change is the last used line. Scope, declared line, type remain the same, as we're not redefining/reassigning the identifier
	/*It is a recursive function.
	If the identifier is not found in the ST of the current scope,
	it searches for it in the ST of the parent scope, recursively.
	Eventually, it reaches the base condition, where the scope becomes the root level scope, and there are no more parent scopes.
	If the identifier is not found even here, it means it's never been declared. Error gets thrown*/	
	void modifyRecordID(const char *type, const char *name, int lineNo, int scope)
	{
		int i =0;
		
		//changed int index = scopeBasedTableSearch(scope);
		//added
		int FScope = hashScope(scope);
		int index = scopeBasedTableSearch(FScope);
		
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
		return modifyRecordID(type, name, lineNo, symbolTables[symbolTables[index].Parent].STscope);
	}
	
	
	
	//this is called whenever an identifier is encountered during an assignment 
	//(identifier is the LHS of assignment stmt)
	/*ex-
	a=20
	a="hello"
	b=[1,2,3]
	*/
	//inserts a new record into ST only if it's not found in any of the scopes
	//else, if that identifier is already in one ST, it just updates the scope, type, declared line, last used line
	/*void insertEntry(const char* type, const char *name, int lineNo, int scope)
	{ 
		//changed int FScope = power(scope, arrayScope[scope]);   //getting scope of identifier
		//changed int index = scopeBasedTableSearch(FScope);      //finding appropriate ST, based on scope
		
		//added
		int FScope = hashScope(scope);
		int index = scopeBasedTableSearch(FScope);
		
		
		int recordIndex = searchRecordInScope(type, name, index);
		//if the identifier has never been seen before in that scope, create a new record entry for this identifier
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
		//otherwise, it just updates the type, declared line, and line of last use
		else
		{
			strcpy(symbolTables[i].Elements[j].type, type);
			symbolTables[index].Elements[recordIndex].lineno_declared = lineNo;
			symbolTables[index].Elements[recordIndex].lastUseLine = lineNo;
		}
	}*/
	
//********************************************************************************************************************	
	//below function inserts each identifier only once. slightly flawed, as it should insert multiple times if they're in different scopes, but it doesn't.
	/*(ex-
	1 a=10
	2 if condition:
	3	a=20
		
	below function inserts 'a' only once, and says it's been declared at line 3. but if the condition is false, the compiler needs the definition at line 1. it won't be able to access it in this case, as there is only one entry for 'a'.
	therefore, two entries for 'a' needed, for two different scopes (line 1, line 3). based on the flow of control, compiler can access the correct definition.
	therefore, the function needs to search for the identifier in the current scope. if found, just update its declared line, last used line, and type.
	if it's not found in the current scope, create a new record entry for this identifier, in this scope 
	*/
	void insertEntry(const char* type, const char *name, int lineNo, int scope)
	{ 
		
		
		//added
		int FScope = hashScope(scope);  //to get the hashed scope of current line
		int index = scopeBasedTableSearch(FScope);   //to get the corresponding ST, based on scope
		
		
		
		//*****************
		
		int foundflag=0;
		int freedflag=0;
		
		//search for the identifier's entry in a ST, if present
		//(if identifier seen before, in some scope)
		int i, j;
		//for each ST
		for(i=0; i<=sIndex && !foundflag; i++)
		{
			//for each record in ST
			for(j=0; j<symbolTables[i].noOfElements && !foundflag; j++)
			{
				//if the identifier is found
				if(strcmp(symbolTables[i].Elements[j].name, name)==0)
				{
					foundflag = 1;
				
					//if the scope of redefined identifier is the same as its previous definition (if scope of current ST matches scope of redefined identifier)
					//(we can just modify the entry for this identifier in the current ST, as the scope doesn't change)
					if(symbolTables[i].STscope == scope)
					{
						
						strcpy(symbolTables[i].Elements[j].type, type);
						symbolTables[i].Elements[j].lineno_declared = lineNo;
						symbolTables[i].Elements[j].lastUseLine = lineNo;
						
					}
					//if a previous definition is found, but its scope is different from the scope of the new definition
					//have to delete old entry, and create new entry in different ST (based on scope) (creating done in next block)
					else
					{
						freedflag=1;
						
						free(symbolTables[i].Elements[j].name);
						free(symbolTables[i].Elements[j].type);
					}
				
					
				}
			}
		}
		
		//if the identifier has never been seen before in any scope/if redefining is in different scope, create new record entry in appropriate ST (based on scope)
		if(foundflag==0 || freedflag==1)
		//if(recordIndex==-1)
		{
			
			symbolTables[index].Elements[symbolTables[index].noOfElements].type = (char*)calloc(30, sizeof(char));
			symbolTables[index].Elements[symbolTables[index].noOfElements].name = (char*)calloc(20, sizeof(char));
			strcpy(symbolTables[index].Elements[symbolTables[index].noOfElements].type, type);	
			strcpy(symbolTables[index].Elements[symbolTables[index].noOfElements].name, name);
			
			symbolTables[index].Elements[symbolTables[index].noOfElements].lineno_declared = lineNo;
			symbolTables[index].Elements[symbolTables[index].noOfElements].lastUseLine = lineNo;
			symbolTables[index].noOfElements++;

		}
	}
//********************************************************************************************************************
	
	
		
	
	
	//checking to see if the identifier accessed is a list, by looking at the 'type' in the symbol table entry for that record
	//if type turns out to be anything other than list, error thrown, saying the identifier is not an iterable, and can't be indexed
	/*This is also a recursive function
	Works like modifyRecordID function*/	
	void checkIfList(const char *name, int lineNo, int scope)
	{
		//changed int index = scopeBasedTableSearch(scope);
		//added
		int FScope = hashScope(scope);
		int index = scopeBasedTableSearch(FScope);
		
		
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
		
		return checkIfList(name, lineNo, symbolTables[symbolTables[index].Parent].STscope);

	}
	
	//prints all the STs (from all the scopes)
	void printSymbolTables()
	{
		int i = 0, j = 0;
		
		printf("\n----------------------------Symbol Tables----------------------------");
		printf("\nScope\t\t\tName\t\t\tType\t\t\tDeclaration\t\t\tLast Used Line\n");
		for(i=0; i<=sIndex; i++)
		{
			for(j=0; j<symbolTables[i].noOfElements; j++)
			{
				//changed printf("(%d, %d)\t\t\t%s\t\t\t%s\t\t\t%d\t\t\t%d\n", symbolTables[i].Parent, symbolTables[i].STscope, symbolTables[i].Elements[j].name, symbolTables[i].Elements[j].type, symbolTables[i].Elements[j].lineno_declared,  symbolTables[i].Elements[j].lastUseLine);
				
				//added
				printf(" %d\t\t\t%s\t\t\t%s\t\t\t%d\t\t\t%d\n", symbolTables[i].STscope, symbolTables[i].Elements[j].name, symbolTables[i].Elements[j].type, symbolTables[i].Elements[j].lineno_declared,  symbolTables[i].Elements[j].lastUseLine);
				
				
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


//can use identifiers from lex
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
(so that the elif/else if associated with the closer if), which is what we need*/
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

