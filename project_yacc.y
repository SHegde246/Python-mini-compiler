%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include <stdarg.h>  //needed for variable number of arguments in pushOp function

	#include <math.h>
	
	#define MAX_ENTRIES 200  //(in ST)
	#define MAX_ST 100    //max no of ST
	
	#define MAXARRAYSCOPE 256
	
	#define MAXCHILDREN 100    //max no. of children an AST node can have
	#define MAXLEVELS 20    //max no. of levels in AST
	#define MAXQUADS 1000    //max no. of quads
	
	extern int yylex();
	void yyerror(const char *s);
	
	extern FILE *yyin;
	extern int yylineno;
	extern int level;
	extern int top();
	extern int pop();
	
	
	FILE* ftac=NULL;
	FILE* fquads=NULL;
	FILE* fsym=NULL;
	
	
	//changed int currentScope = 1;
	int currentScope = 0;
	
	
	int scopeChange = 0; //flag
	
	int *arrayScope = NULL;
	
	//structure of a single record in a symbol table
	typedef struct record
	{
		char *type;
		char *name;
		char *datatype;
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
	
	
	
	//structure for Abstract Syntax Tree node
	typedef struct ASTNode
	{
		int nodeNo;
	    	char *NType;    //if the Node is an operator (specifies the operator. ex- +, -, etc)
		int opCount;    //number of operands (children) of the operator node
	    	struct ASTNode** NextLevel;
	    	record *id;    //if the Node is an identifier or a constant, this node needs to point to a record in a ST
	} Node;
	
	
	//structure for Quad
	typedef struct Quad
	{
		char *Op;    //operator
		char *A1;    //argument 1
		char *A2;    //argument 2
		char *R;    //result
		
		//can be used to mark a quad as redundant during common subexpression, dead code elimination
		int I;    //(initially holds index no. of the quad in the array)
	} Quad;
	
	
	Node *rootNode;
	Quad *quad_array = NULL;
	Node ***Tree = NULL;
	Node * e1, * e2, * e3 = NULL;

	char g_dataType[100] = "";
	int aIndex = -1, tabCount = 0, tIndex = 0;
	
	int label_index = 0;  //assigns label number (1,2,3 etc for L1,L2,L3, etc)
	 
	int NodeCount = 0;  //no. of nodes in AST
	int qIndex = 0;    //index of last element in array of quads (keeps track of number of quads)
	char *argsList = NULL;
	
	char *tString = NULL;    //to store temp variable (ex- T0, T5, etc)
	char *lString = NULL;    //to store temp label (label of block, used with goto (goto L0)) (ex- L0, L2, etc)
	
	int *levelIndices = NULL;
	
	/*-----------------------------------------------------------Function Declarations----------------------------------------------------------------*/
	
	void init();
	void initNewTable(int scope);
  	//int power(int base, int exp);
  	void updateCScope(int scope);
  	void resetDepth();
	int scopeBasedTableSearch(int scope);
	int searchRecordInScope(const char* type, const char *name, int index);
	record* modifyRecordID(const char *type, const char *name, int lineNo, int scope);
	void insertEntry(const char* type, const char *name, const char* datatype, int lineNo, int scope);
	void checkIfList(const char *name, int lineNo, int scope);
	void printSymbolTables();
	void freeAll();
	
	int hashScope(int codeScope);
	
	
	record* findRecord(const char *name, const char *type, int codeScope);
	Node *pushID_Const(char *value, char *type, int codeScope);
	void addToList(char *newVal, int flag);
	void clearArgsList();
	int isBinOp(char *Op);
	int tempNum(char* arr);
	void printQuads(char *text);
	void printAST(Node *root);
	void ASTToArray(Node *root, int level);

	
	/*-----------------------------------------------------------------------------------------------------------------------------------------------*/
	
	//allocates memory needed for all the data structures
	void init()
	{
		int i = 0;
		symbolTables = (STable*)calloc(MAX_ST, sizeof(STable));
		arrayScope = (int*)calloc(MAXARRAYSCOPE, sizeof(int));
		
		//changed initNewTable(1);
		initNewTable(++currentScope);
		
		//allocates memory and initialises argslist to empty string
		//this string appends arguments of a function definition/call, separated by commas, so that they can be passed as a single unit to AST node (ex- "arg1, arg2, arg3"), which can further be used during ICG
		argsList = (char *)malloc(100);
		strcpy(argsList, "");
		
		tString = (char*)calloc(10, sizeof(char));
		lString = (char*)calloc(10, sizeof(char));
		quad_array = (Quad*)calloc(MAXQUADS, sizeof(Quad));
		
		levelIndices = (int*)calloc(MAXLEVELS, sizeof(int));
		Tree = (Node***)calloc(MAXLEVELS, sizeof(Node**));
		for(i = 0; i<MAXLEVELS; i++)
		{
			Tree[i] = (Node**)calloc(MAXCHILDREN, sizeof(Node*));
		}
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
			//checking for type, too, because a Func_Name type and Identifier type may have the same name
			//therefore, in case we have a function and an identifier with the same name, have to make sure that the name corresponds to an identifier
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
	//Here, the only information about the identifier that needs to change is the last used line. Scope, declared line, type remain the same, as we're not redefining/reassigning the identifier (the scope in which it was defined doesn't change, only the place of usage does)
	/*It is a recursive function.
	If the identifier is not found in the ST of the current scope,
	it searches for it in the ST of the parent scope, recursively.
	Eventually, it reaches the base condition, where the scope becomes the root level scope, and there are no more parent scopes.
	If the identifier is not found even here, it means it's never been declared. Error gets thrown*/	
	record* modifyRecordID(const char *type, const char *name, int lineNo, int scope)
	{
		int i=0;
		
		//changed int index = scopeBasedTableSearch(scope);
		//added
		int FScope = hashScope(scope);    //getting hashed value of current scope
		int index = scopeBasedTableSearch(FScope);    //finding the ST, corresponding to that scope
		
		if(index==0)
		{
			for(i=0; i<symbolTables[index].noOfElements; i++)
			{
				
				if(strcmp(symbolTables[index].Elements[i].type, type)==0 && (strcmp(symbolTables[index].Elements[i].name, name)==0))
				{
					symbolTables[index].Elements[i].lastUseLine = lineNo;
					return &(symbolTables[index].Elements[i]);
				}	
			}
			printf("\nERROR: %s '%s' at line %d Not Declared\n", type, name, yylineno);
			exit(1);
		}
		
		//iterate through all the entries in the ST of current scope
		for(i=0; i<symbolTables[index].noOfElements; i++)
		{
			if(strcmp(symbolTables[index].Elements[i].type, type)==0 && (strcmp(symbolTables[index].Elements[i].name, name)==0))
			{
				symbolTables[index].Elements[i].lastUseLine = lineNo;
				return &(symbolTables[index].Elements[i]);
			}	
		}
		return modifyRecordID(type, name, lineNo, symbolTables[symbolTables[index].Parent].STscope);
	}
	
	//searches for ST entry for an identifier in all the scopes
	//recursive function, recursion logic similar to modifyRecordID function
	record* findRecord(const char *name, const char *type, int scope)
	{
		int i=0;
		int FScope = hashScope(scope);    //getting hashed value of current scope
		int index = scopeBasedTableSearch(FScope);    //finding the ST, corresponding to that scope

		//base condition (if scope reaches outermost)
		if(index==0)
		{
			for(i=0; i<symbolTables[index].noOfElements; i++)
			{
				
				if(strcmp(symbolTables[index].Elements[i].type, type)==0 && (strcmp(symbolTables[index].Elements[i].name, name)==0))
				{
					return &(symbolTables[index].Elements[i]);
				}	
			}
			printf("\n%s '%s' at line %d not found in Symbol Table at current scope %d \n", type, name, yylineno, scope);
			exit(1);
		}
		
		//iterate through all the entries in the ST of current scope
		for(i=0; i<symbolTables[index].noOfElements; i++)
		{
			if(strcmp(symbolTables[index].Elements[i].type, type)==0 && (strcmp(symbolTables[index].Elements[i].name, name)==0))
			{
				return &(symbolTables[index].Elements[i]);
			}	
		}

	//search for record in parent/enclosing scope (ST with previous scope)
	return findRecord(name, type, scope-1);
	}
	
	
	
	//this is called whenever an identifier is encountered during an assignment 
	//(identifier is the LHS of assignment stmt)
	/*ex-
	a=20
	a="hello"
	b=[1,2,3]
	*/
	//inserts a new record into a ST only if it's not found in current scope
	//else, if that identifier is already in ST, it just updates the declared line, last used line
	
	//therefore, one identifier has only one entry in a particular scope (ST). 
	//an identifier cannot have two entries in the same scope, but can have more than one entry if they all belong to different scopes
	void insertEntry(const char* type, const char *name, const char * datatype, int lineNo, int scope)
	{ 
		//changed int FScope = power(scope, arrayScope[scope]);   //getting scope of identifier
		//changed int index = scopeBasedTableSearch(FScope);      //finding appropriate ST, based on scope
		
		//added
		int FScope = hashScope(scope);    //getting hashed scope of identifier
		int index = scopeBasedTableSearch(FScope);    //finding the ST, corresponding to that scope
		
		
		int recordIndex = searchRecordInScope(type, name, index);    //finding the record for that identifier in the ST, if present
		//if the identifier has never been seen before in that scope, create a new record entry for the identifier
		if(recordIndex==-1)
		{
			
			symbolTables[index].Elements[symbolTables[index].noOfElements].type = (char*)calloc(30, sizeof(char));
			symbolTables[index].Elements[symbolTables[index].noOfElements].name = (char*)calloc(20, sizeof(char));
			symbolTables[index].Elements[symbolTables[index].noOfElements].datatype = (char*)calloc(50, sizeof(char));
			
			
			strcpy(symbolTables[index].Elements[symbolTables[index].noOfElements].type, type);	
			strcpy(symbolTables[index].Elements[symbolTables[index].noOfElements].name, name);
			strcpy(symbolTables[index].Elements[symbolTables[index].noOfElements].datatype, datatype);
			
			
			symbolTables[index].Elements[symbolTables[index].noOfElements].lineno_declared = lineNo;
			symbolTables[index].Elements[symbolTables[index].noOfElements].lastUseLine = lineNo;
			symbolTables[index].noOfElements++;

		}
		//otherwise, if the identifier has alrady been defined in that scope, it just updates the declared line, and line of last use
		else
		{
			symbolTables[index].Elements[recordIndex].lineno_declared = lineNo;
			symbolTables[index].Elements[recordIndex].lastUseLine = lineNo;
		}
	}
	
		
	
	
	//checking to see if the identifier accessed is a list, by looking at the 'type' in the symbol table entry for that record
	//if type turns out to be anything other than list, error thrown, saying the identifier is not an iterable, and can't be indexed
	/*This is also a recursive function
	Works like modifyRecordID function*/	
	void checkIfList(const char *name, int lineNo, int scope)
	{
		//changed int index = scopeBasedTableSearch(scope);
		//added
		int FScope = hashScope(scope);    //getting hashed value of current scope
		int index = scopeBasedTableSearch(FScope);    //finding the ST, corresponding to that scope
		
		
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
		
		//iterate through all the entries in the ST of current scope
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
	
	
	//*********************************************************
	
	void makeQuad(char *R, char *A1, char *A2, char *Op)
	{
		//add a quadruple record 
		quad_array[qIndex].R = (char*)malloc(strlen(R)+1); //+1 to account for null character at the end of string
		quad_array[qIndex].Op = (char*)malloc(strlen(Op)+1);
		quad_array[qIndex].A1 = (char*)malloc(strlen(A1)+1);
		quad_array[qIndex].A2 = (char*)malloc(strlen(A2)+1);
		
		strcpy(quad_array[qIndex].R, R);
		strcpy(quad_array[qIndex].A1, A1);
		strcpy(quad_array[qIndex].A2, A2);
		strcpy(quad_array[qIndex].Op, Op);
		quad_array[qIndex].I = qIndex;

		qIndex++;
		
		return;
	}
	
	//no binary minus here (as there is unary minus, both binary and unary are dealt with separately)
	//function to help with determining the type of binary operator
	int isBinOp(char *Op)
	{
	    if((strcmp(Op, "+")==0) || (strcmp(Op, "*")==0) || (strcmp(Op, "/")==0)) {
	      return 1;  //arithmetic operator
	    } else if ((strcmp(Op, ">=")==0) || (strcmp(Op, "<=")==0) || (strcmp(Op, "<")==0) || (strcmp(Op, ">")==0)) {
	      return 2;  //relational operator
	    } else if ((strcmp(Op, "==")==0) || (strcmp(Op, "and")==0) || (strcmp(Op, "or")==0)) {
				return 3;  //logical/boolean operator
	    } else if (strcmp(Op, "in") == 0) {
	      return 4;  //membership operator
	    }else {
				return 0;
		}
	}
	
	
	
	
	
	
	/*-------------------------------------------------- Abstract Syntax Tree --------------------------------------------------*/
	
	//creating AST node, when node is an identifier/constant
	Node *pushID_Const(char *type, char *value, int codeScope)
	{
		char *val = value;
		Node *newNode;  //create node of Node type
		newNode = (Node*)calloc(1, sizeof(Node));  //allocate memory to this new node
		newNode->NType = NULL;  //NType is for operator nodes only (this is id/const node)
		newNode->opCount = -1;  //leaf node, therefore no operands/children
		newNode->id = findRecord(value, type, codeScope);
		newNode->nodeNo = NodeCount++;  //assigns a number to the node by increasing node count
		return newNode;
	}	
	
	//creating AST node, when node is an operator
	//also attaches association with the children
	/* Variable Number of arguments-
	-'...' refers variable number of arguments.
	-opCount is an integer which specifies how many arguments (children) there are.
	-Create a va_list type (params) variable in the function definition.
	-Use int parameter (opCount) and va_start macro to initialize the va_list variable to an argument list.
	-Use va_arg macro and va_list variable (params) to access each item in argument list.
	-Use a macro va_end to clean up the memory assigned to va_list variable.
	*/
	Node *pushOp(char *oper, int opCount, ...)
	{
		va_list params;
		Node *newNode;  //create node of Node type
	    	int i;
	   	newNode = (Node*)calloc(1, sizeof(Node));  //allocate memory to this new node
	    	newNode->NextLevel = (Node**)calloc(opCount, sizeof(Node*));  //the operator node's NextLevel has enough memory to store nodes for all its children (size of (opCount * Node))
	    	newNode->NType = (char*)malloc(strlen(oper)+1);  //allocates memory for the operator (oper holds the operator as a string, ex- "+", ">=", etc)
	    	strcpy(newNode->NType, oper);
	    	newNode->opCount = opCount;    //specifies the number of children/arguments of this operator node
		va_start(params, opCount);
	    
	    	for (i = 0; i < opCount; i++)
	    	{
	    		//each argument in the variable list is of Node type
	    		//each of these arguments is assigned to a NextLevel (child) node of the operator node, thereby associating the operator node with its children nodes
		   	newNode->NextLevel[i] = va_arg(params, Node*);
		}
	    
		va_end(params);  //cleans memory reserved for valist
	    	newNode->nodeNo = NodeCount++;  //assigns a number to the node by increasing node count
	    	return newNode;
	}
	
	
	//this string appends arguments of a function definition/call, separated by commas, so that they can be passed as a single unit to AST node (ex- "arg1, arg2, arg3" = a node)
	void addToList(char *newVal, int flag)
	{
		//adding subsequent arguments to list
		if(flag==0)
	  	{
			strcat(argsList, ", ");
			strcat(argsList, newVal);
		}
		
		//adding first argument to list
		else
		{
			strcat(argsList, newVal);
		}
	}
  
	void clearArgsList()
	{
	    strcpy(argsList, "");
	}
 

	void ASTToArray(Node *root, int level)
	{
		  if(root == NULL )
		  {
		    return;
		  }
		  
		  if(root->opCount <= 0)
		  {
		  	Tree[level][levelIndices[level]] = root;
		  	levelIndices[level]++;
		  }
			  
		  if(root->opCount > 0)
		  {
		  	int j;
		 	Tree[level][levelIndices[level]] = root;
			levelIndices[level]++; 
		    	for(j=0; j<root->opCount; j++)
			{
			    	ASTToArray(root->NextLevel[j], level+1);
			}
		  }
	}
	
	
	
	/* ------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
	
	//used during strength reduction in optimisation
	int pow2(int num)
	{
		float x=log2(num);
		int xi= (int)x;

		if(x-xi==0.0)
			return xi;
		else
			return 0;
	}
	
	//used during IR generation
	/*input is the name of the temp variable in string form, ex- T15.
	the function extracts the number part, and converts it to integer.
	output = 15.
	*/
	int tempNum(char* arr)  //ex- T15
	{
		int i =0, l=sizeof(arr); //3
		int ll=l-1;  //2
		char ret[ll];  //[ , ]
		for(i=1;i<l;i++)
		{
			ret[i-1]=arr[i];
		}  //ret=["1","5"]
		return atoi(ret);  //15 (int)
	}
	
	//stores a number in str, the character buffer
	void append_buffer(int num, char *str)
	{
		if(str == NULL)
		{
		   printf("Allocate Memory\n");
		   return;
		}
		sprintf(str, "%d", num);
	}
	
	//for intermediate code (temps/labels) in ST
	//returns name of temp/label
	//ex- T3, L1, etc
	char *makeStr(int no, int flag, char *datatype)
	{
		
		char A[10];
		append_buffer(no, A);  //no gets stored in A
		
		if(flag==1)
		{
			//to store temp variable (ex- T0, T5, etc)
			strcpy(tString, "T");
			strcat(tString, A);  //appends the no. stored in A to "T". ex- T4
			insertEntry("TempVar", tString, datatype, -1, 1);
			return tString;
		}
		else
		{
			 //to store temp label (label of block, used with goto (goto L0)) (ex- L0, L2, etc)
			strcpy(lString, "L");
			strcat(lString, A);  //appends the no. stored in A to "L". ex- L2
			insertEntry("TempLabel", lString, "N/A", -1, 1);
			return lString;
		}

	}
	
	
	
	/* -------------------------------------------------- Intermediate Code Generation --------------------------------------------------*/
	
	//creates TAC, quad for each AST node
	void genCode(Node *opNode)
	{
		int i=0;
		if(opNode == NULL)
		{
			fprintf(ftac,"opNode is null");
			//printf("opNode is null\n");
			return;
		}
		//**********************************
			
		//if it is an identifier/constant node
		if(opNode->NType == NULL)
		{
			if((strcmp(opNode->id->type, "Identifier")==0) || (strcmp(opNode->id->type, "Constant")==0))
			{
				//three address code
				
				int flag=0,i=0;
				//iterating through quads
				for(i=0; i<qIndex; i++)
				{
					//if the node's identifier's name is the result of any of the quads (if the result of the operation is stored in this identifier)
					//if there is only one argument
					//if operator is "="
					//ex- T0=x
					if((strcmp(opNode->id->name,quad_array[i].R)==0) && (strcmp(quad_array[i].A2,"-")==0) && (strcmp(quad_array[i].Op,"=")==0))			
						{
							flag=1;
							break;
						}
				
				}
				
				if(flag==1)
				{
					fprintf(ftac,"%s = %s\n",quad_array[i].A1, opNode->id->name);
					//printf("%s = %s\n",quad_array[i].A1, opNode->id->name);
					
					
					int n=tempNum(quad_array[i].A1);  //retrieves the number part of the temporary name (ex- retrieves 15 from T15)
					makeQuad(makeStr(n,1, "unknown"), opNode->id->name, "-", "=");
						
				}
				
				else
				{	
					fprintf(ftac,"T%d = %s\n", opNode->nodeNo, opNode->id->name);
					//printf("T%d = %s\n", opNode->nodeNo, opNode->id->name);
					
					makeQuad(makeStr(opNode->nodeNo, 1, "TempVarType"), opNode->id->name, "-", "=");
				}
			}
			return;
		}
		//**********************************
		
		//ex- a=T0
		//node= "=", node's next level [0] = "a", node's next level [1] = "T0"
		if(strcmp(opNode->NType, "=")==0)
		{
			genCode(opNode->NextLevel[1]); //for RHS node of assignment
		
			fprintf(ftac,"%s = T%d\n", opNode->NextLevel[0]->id->name, opNode->NextLevel[1]->nodeNo);
			//printf("%s = T%d\n", opNode->NextLevel[0]->id->name, opNode->NextLevel[1]->nodeNo);
			
			makeQuad(opNode->NextLevel[0]->id->name, makeStr(opNode->NextLevel[1]->nodeNo, 1, "TempVarType"), "-", opNode->NType);
			
			return;
		}
		//**********************************
		
		int bin = isBinOp(opNode->NType);  //checks if operator is binary
		//ex- a>=b, c*d, x and y
		//result = operand1 operator operand2
		if(bin)  // => node has two children
		{
			
			//generate TAC for both of the children/arguments
			genCode(opNode->NextLevel[0]);
			genCode(opNode->NextLevel[1]);
					
			char *X1 = (char*)malloc(10);  //temporary created to hold value of result of operation
			char *X2 = (char*)malloc(10);  //temporary created to hold value of first argument
			char *X3 = (char*)malloc(10);  //temporary created to hold value of second argument
			
			//r, t1, t2 hold data types
	    		char* r = (char*)malloc(10);  //holds data type of result of operation
	    		char* t1 = (char*)malloc(10);  //holds data type of first argument
		    	char* t2 = (char*)malloc(10);  //holds data type of second argument
			
	   	 	if (bin == 1)  //arithmetic operator
	   	 	{
	   	   		strcpy(r, "int");
				strcpy(t1, "int");
				strcpy(t2, "int");
			} 
			else if (bin == 2)  //relational operator
			{
		 		strcpy(r, "bool");
				strcpy(t1, "int");
				strcpy(t2, "int");
			} 
			else if (bin == 3)  //logical/boolean operator
			{
				strcpy(r, "bool");
				strcpy(t1, "bool");
				strcpy(t2, "bool"); 
			} 
			else if (bin == 4)  //membership operator
			{
				strcpy(r, "bool");
				strcpy(t1, "unknown");
				strcpy(t2, "list"); 
			}
			strcpy(X1, makeStr(opNode->nodeNo, 1,r));
			
			
			int left=0,right=0,i=0,j=0,flag=0;
			//iterating through quads
			for(i=0; i<qIndex; i++)
			{
				//if both arguments/children/operands are not identifiers
				//(they are both temps) 
				if( (!opNode->NextLevel[0]->id) || (!opNode->NextLevel[1]->id) )
					break;
					
				//if operand1 is the result field of some quad, and there's only one argument in this quad, and if it's an assignment statement
				//ex- operand1 = 20
				//operand1 is an identifier
				if((left!=1) && (strcmp(opNode->NextLevel[0]->id->name,quad_array[i].R)==0) && (strcmp(quad_array[i].A2,"-")==0) && (strcmp(quad_array[i].Op,"=")==0))			
				{
					left=1;
					j=i;  //capturing the index of the quad
				}
				
				//if operand2 is the result field of some quad, and there's only one argument in this quad, and if it's an assignment statement
				//ex- operand2 = 15
				//operand2 is an identifier	
				if((right!=1) && (strcmp(opNode->NextLevel[1]->id->name,quad_array[i].R)==0) && (strcmp(quad_array[i].A2,"-")==0) && (strcmp(quad_array[i].Op,"=")==0))			
				{
					right=1;
				}
				
				/*there exists both
				ex-
				operand1 = 20
				operand2 = 15
				*/
				//both operand1 and operand2 are identifiers 
				if(left!=0 && right!=0)
					break;
				
			}
			
			/*there exists both ex-
				operand1 = 20
				operand2 = 15*/	
			if(left==1 && right==1)
				flag=1;
			//there exists only operand1 = 20 (example)
			//operand2 is a temp
			else if(right==0 && left!=0)
				flag=2;
			//there exists only operand2 = 15 (example)
			//operand1 is a temp
			else if(right!=0 && left==0)
				flag=3;	
			
			
			
			//there exists both operand1 = 20 and operand2 = 15 (example)
			//result stored in temp
			/* the tree looks something like this
			                +
			   	 id1          id2
			*/
			//depth of both branches is one, so the values of their identifiers can directly be substituted 
			if(flag==1)
			{
				fprintf(ftac,"T%d = %s %s %s\n", opNode->nodeNo, quad_array[j].A1, opNode->NType, quad_array[i].A1);
				
				//printf("T%d = %s %s %s\n", opNode->nodeNo, quad_array[j].A1, opNode->NType, quad_array[i].A1);
				
				int m=tempNum(quad_array[i].A1);
				int n=tempNum(quad_array[j].A1);
				
				strcpy(X2, makeStr(n, 1, t1));
				strcpy(X3, makeStr(m, 1, t2));	
			}
			
			
			
			//operand1 is directly substituted. operand2 is a temp
			//depth of first branch from operator is one. depth of other branch is more than one, therefore, that child will be a temp. 
			/* the tree looks something like this
			                +
			   	 id1          temp
			    		id2        id3
			*/  		
			else if(flag==2)
			{
				fprintf(ftac,"T%d = %s %s T%d\n", opNode->nodeNo, quad_array[j].A1, opNode->NType, opNode->NextLevel[1]->nodeNo);
				//printf("T%d = %s %s T%d\n", opNode->nodeNo, quad_array[j].A1, opNode->NType, opNode->NextLevel[1]->nodeNo);
				
				int n=tempNum(quad_array[j].A1);
				strcpy(X2, makeStr(n, 1, t1));
				strcpy(X3, makeStr(opNode->NextLevel[1]->nodeNo, 1, t2));	
			}
			
			
			//operand2 is directly substituted. operand1 is a temp
			//depth of second branch from operator is one. depth of other branch is more than one, therefore, that child will be a temp. 
			/* the tree looks something like this
			                +
			        temp		id3
			    id1        id2
			*/  	
			else if(flag==3)
			{
				fprintf(ftac,"T%d = T%d %s %s\n", opNode->nodeNo, opNode->NextLevel[0]->nodeNo, opNode->NType, quad_array[i].A1);
				//printf("T%d = T%d %s %s\n", opNode->nodeNo, opNode->NextLevel[0]->nodeNo, opNode->NType, quad_array[i].A1);
				
				int n=tempNum(quad_array[j].A1);
				strcpy(X2, makeStr(opNode->NextLevel[0]->nodeNo, 1, t1));
				strcpy(X3, makeStr(n, 1, t2));	
			}	
			
			
			//both operands are temps
			/* the tree looks something like this
			                  +
			        temp1		 temp2
			    id1        id2   id3	id4
			*/  	
			else
			{		
				strcpy(X2, makeStr(opNode->NextLevel[0]->nodeNo, 1, t1));
				strcpy(X3, makeStr(opNode->NextLevel[1]->nodeNo, 1, t2));
				fprintf(ftac,"T%d = T%d %s T%d\n", opNode->nodeNo, opNode->NextLevel[0]->nodeNo, opNode->NType, opNode->NextLevel[1]->nodeNo);
				//printf("T%d = T%d %s T%d\n", opNode->nodeNo, opNode->NextLevel[0]->nodeNo, opNode->NType, opNode->NextLevel[1]->nodeNo);
			}
				
			makeQuad(X1, X2, X3, opNode->NType);
			free(X1);
			free(X2);
			free(X3);
			
			return;
		}
		//**********************************
		
		if(strcmp(opNode->NType, "For")==0)
		{
			int temp = label_index;
			
			//for the (loop variable = lower range limit) child
			genCode(opNode->NextLevel[0]);
			fprintf(ftac,"\nL%d: ", label_index);
			//printf("\nL%d: ", label_index);
			makeQuad(makeStr(temp, 0, "LabelType"), "-", "-", "Label");		
			
			//for the (loop variable >= lower range limit) child
			genCode(opNode->NextLevel[1]);
			fprintf(ftac,"If False T%d goto L%d\n", opNode->NextLevel[1]->nodeNo, temp+1);
			makeQuad(makeStr(temp+1, 0, "LabelType"), makeStr(opNode->NextLevel[1]->nodeNo, 1, "TempVarType"), "-", "If False");	

			//for the (loop variable < upper range limit) child
			genCode(opNode->NextLevel[2]);
			fprintf(ftac,"If False T%d goto L%d\n", opNode->NextLevel[2]->nodeNo, temp+1);
			makeQuad(makeStr(temp+1, 0, "LabelType"), makeStr(opNode->NextLevel[2]->nodeNo, 1, "TempVarType"), "-", "if false");	

			//for the begin_block child
			genCode(opNode->NextLevel[3]);
			fprintf(ftac,"goto L%d\n", temp);
			makeQuad(makeStr(temp, 0, "LabelType"), "-", "-", "goto");
			
			//for the block it should go to if the condition is false
			fprintf(ftac,"L%d: ", temp+1);
			makeQuad(makeStr(temp+1, 0, "LabelType"), "-", "-", "Label"); 
			label_index = label_index+2;  //two labels taken up. one for goto label1 if true, one for goto label2 false. therefore, increase index by 2
			return;
		}
		//**********************************
		
	
		if((!strcmp(opNode->NType, "If")) || (!strcmp(opNode->NType, "Elif")))
		{	
			//checks for number of children passed to the function pushOp for "if_stmt"		
			switch(opNode->opCount)
			{
				//standalone if
				case 2 : 
				{
					int temp = label_index;
					
					//TAC for boolean condition of if
					genCode(opNode->NextLevel[0]);
					fprintf(ftac, "If False T%d goto L%d\n", opNode->NextLevel[0]->nodeNo, label_index);
					//makeQuad(res=L_, arg1=bool condn, arg2="-", operation="If False")
					makeQuad(makeStr(temp, 0, "LabelType"), makeStr(opNode->NextLevel[0]->nodeNo, 1, "TempVarType"), "-", "If False");
					label_index++;
					
					//TAC for if block statements
					genCode(opNode->NextLevel[1]);
					label_index--;
					fprintf(ftac, "L%d: ", temp);
					makeQuad(makeStr(temp, 0, "LabelType"), "-", "-", "Label");
					break;
				}
				
				//if with elif/else
				case 3 : 
				{
					int temp = label_index;
					
					//TAC for boolean condition of if
					genCode(opNode->NextLevel[0]);
					fprintf(ftac, "If False T%d goto L%d\n", opNode->NextLevel[0]->nodeNo, label_index);
					makeQuad(makeStr(temp, 0, "LabelType"), makeStr(opNode->NextLevel[0]->nodeNo, 1, "TempVarType"), "-", "If False");	
					
					//TAC for if block statements				
					genCode(opNode->NextLevel[1]);
					fprintf(ftac, "goto L%d\n", temp+1);
					makeQuad(makeStr(temp+1, 0, "LabelType"), "-", "-", "goto");
					fprintf(ftac, "L%d: ", temp);
					makeQuad(makeStr(temp, 0, "LabelType"), "-", "-", "Label");
					
					//TAC for elif/else statements
					genCode(opNode->NextLevel[2]);
					fprintf(ftac, "L%d: ", temp+1);
					makeQuad(makeStr(temp+1, 0, "LabelType"), "-", "-", "Label");
					label_index+=2;
					break;
				}
			}
			return;
		}
		
		if(!strcmp(opNode->NType, "Else"))
		{
			//next level would contain the else block statements
			genCode(opNode->NextLevel[0]);
			return;
		}
		//**********************************

		//look at the CFG to see what the children are (what's getting pushed in pushOp function)
		
		if(strcmp(opNode->NType, "Next")==0)
		{
			genCode(opNode->NextLevel[0]);  //finalStatements
			genCode(opNode->NextLevel[1]);  //block 
			return;
		}
		//**********************************
		
		if(strcmp(opNode->NType, "StartBlock")==0)
		{
			genCode(opNode->NextLevel[0]);  //finalStatements
			genCode(opNode->NextLevel[1]);  //block		
			return;	
		}
		//**********************************
			
		if(strcmp(opNode->NType, "EndBlock")==0)
		{
			//checks for number of children passed to the function pushOp for "EndBlock" 
			switch(opNode->opCount)
			{
				//end of entire file, last block
				case 0 : 
				{
					break;
				}
				//end of one block, there are more blocks after this
				case 1 : 
				{
					genCode(opNode->NextLevel[0]);  //finalStatements
					break;
				}
			}
			return;
		}
		//**********************************
		
		if(strcmp(opNode->NType, "ListIndex")==0) //children are list's name and index no. value
		{
			fprintf(ftac,"T%d = %s[%s]\n", opNode->nodeNo, opNode->NextLevel[0]->id->name, opNode->NextLevel[1]->id->name);
			makeQuad(makeStr(opNode->nodeNo, 1, "unknown"), opNode->NextLevel[0]->id->name, opNode->NextLevel[1]->id->name, "=[]");
			return;
		}
		//**********************************
		
		//if operator is "-"	
		if(strcmp(opNode->NType, "-")==0)
		{
			//unary minus (one operand)
			if(opNode->opCount == 1)
			{
				//generate TAC for the operand
				genCode(opNode->NextLevel[0]);
				
				char *X1 = (char*)malloc(10);
				char *X2 = (char*)malloc(10);
				strcpy(X1, makeStr(opNode->nodeNo, 1, "unknown")); //temp for result
				strcpy(X2, makeStr(opNode->NextLevel[0]->nodeNo, 1, "unknown")); // temp for operand
				//storing the operand and result in temps
				fprintf(ftac,"T%d = %s T%d\n", opNode->nodeNo, opNode->NType, opNode->NextLevel[0]->nodeNo);
				makeQuad(X1, X2, "-", opNode->NType);	
				
				free(X1);
				free(X2);
				return;
			}
			
			//binary minus (two operands)
			else
			{
				//generate TAC for both operands
				genCode(opNode->NextLevel[0]);
				genCode(opNode->NextLevel[1]);
				
				char *X1 = (char*)malloc(10);
				char *X2 = (char*)malloc(10);
				char *X3 = (char*)malloc(10);
		
				strcpy(X1, makeStr(opNode->nodeNo, 1, "unknown")); //temp for result
				strcpy(X2, makeStr(opNode->NextLevel[0]->nodeNo, 1, "unknown")); //temp for operand1
				strcpy(X3, makeStr(opNode->NextLevel[1]->nodeNo, 1, "unknown")); //temp for operand2
				//storing the operands and result in temps
				fprintf(ftac,"T%d = T%d %s T%d\n", opNode->nodeNo, opNode->NextLevel[0]->nodeNo, opNode->NType, opNode->NextLevel[1]->nodeNo);
				makeQuad(X1, X2, X3, opNode->NType);
				
				free(X1);
				free(X2);
				free(X3);
				return;
			
			}
		}
		//**********************************
		
		//child=module name	
		if(strcmp(opNode->NType, "import")==0)
		{
			fprintf(ftac,"import %s\n", opNode->NextLevel[0]->id->name);
			makeQuad("-", opNode->NextLevel[0]->id->name, "-", "import");
			return;
		}
		//**********************************
		
		//children are newline(T_NL) and StartParse 
		if(strcmp(opNode->NType, "NewLine")==0)
		{
			genCode(opNode->NextLevel[0]);
			genCode(opNode->NextLevel[1]);
			return;
		}
		//**********************************
		
		//children are name of function, arguments, statements under function	
		if(strcmp(opNode->NType, "Func_Name")==0)
		{
			fprintf(ftac,"Begin Function %s\n", opNode->NextLevel[0]->id->name);
			makeQuad("-", opNode->NextLevel[0]->id->name, "-", "BeginF");
			
			//TAC for stmts of function body
			genCode(opNode->NextLevel[2]);
			fprintf(ftac,"End Function %s\n", opNode->NextLevel[0]->id->name);
			makeQuad("-", opNode->NextLevel[0]->id->name, "-", "EndF");
			return;
		}
		//**********************************
		
		//children are name of function, parameters passed	
		if(strcmp(opNode->NType, "Func_Call")==0)
		{
			//if void function (no arguments)
			if(strcmp(opNode->NextLevel[1]->NType, "Void")==0)
			{
				fprintf(ftac,"(T%d)Call Function %s\n", opNode->nodeNo, opNode->NextLevel[0]->id->name);
				makeQuad(makeStr(opNode->nodeNo, 1, "func"), opNode->NextLevel[0]->id->name, "-", "Call");
			}
			
			//if function has arguments
			else
			{
				char A[10];
				
				/*we have argslist passed through semantic value of the CFG
				it is a string of comma-separated arguments
				we want to access each of these arguments (to be used in TAC), so we split(tokenize) the string with the delimiter as ","*/
				//opNode->NextLevel[1]->NType = argslist
				char* token = strtok(opNode->NextLevel[1]->NType, ","); 
	  			int i = 0;
				while (token != NULL) 
				{
	      			i++; 
				    fprintf(ftac,"Push Parameter %s\n", token);
				    makeQuad("-", token, "-", "Param"); 
				    token = strtok(NULL, ","); 
				}
					
				fprintf(ftac,"(T%d)Call Function %s, num_args_%d\n", opNode->nodeNo, opNode->NextLevel[0]->id->name, i); //i => number of arguments
				sprintf(A, "%d", i); //buffer A stores number of arguments passed
				makeQuad(makeStr(opNode->nodeNo, 1, "func"), opNode->NextLevel[0]->id->name, A, "Call");
				fprintf(ftac,"Pop Parameters for Function %s, num_args_%d\n", opNode->NextLevel[0]->id->name, i); //i => number of arguments
								
				return;
			}
		}		
		
	}

	
	
	
	
	/* ------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
	
		
	//*********************************************************
	
	
	/* -------------------------------------------------- Code Optimization --------------------------------------------------*/

	//works only when second argument is a power of two
	void strengthReduction()
	{
		//iterate through the quads
		for(int i=0; i<qIndex; i++)
		{
			//if quad_i has two arguments (second argument is not blank)
			if(strcmp(quad_array[i].A2,"-")!=0)
			{
				//iterate through the quads
				for(int j=0; j<qIndex; j++)
				{
					//if quad_i's operator is "*"
					//and if quad_i's second argument = quad_j's result
					//and if quad_j has only one argument (second argument is blank, therefore, assignment)
					/*ex-
					c = 2  #quad_j
					---
					a = b * c  #quad_i
					*/
					//we need the value of one of the operands (in this case, second operand)
					if((strcmp(quad_array[i].Op,"*")==0) && (strcmp(quad_array[i].A2,quad_array[j].R)==0) && (strcmp(quad_array[j].A2,"-")==0))
					{
						char* ns=(char*)malloc(20);
						
						//for this to work, we need to find a number n such that 2^n = second argument
						int n = pow2(atoi(quad_array[j].A1));

						if(n>0)
						{
							//a << b = a * 2^b
							/* ex- 8 * 2
							= 8 << 1 (8 * 2^1) (n=1)
							       2 * 8
							= 2 << 3 (2 * 2^3) (n=3)
							*/
							quad_array[i].Op="<<";
							sprintf(ns, "%d", n);
							strcpy(quad_array[i].A2,ns);
						}
					}
					
					//if quad_i's operator is "/"
					//and if quad_i's second argument = quad_j's result
					//and if quad_j has only one argument (second argument is blank, therefore, assignment)
					/*ex-
					c = 2  #quad_j
					---
					a = b / c  #quad_i
					*/
					//we need the value of the second operand
					else if((strcmp(quad_array[i].Op,"/")==0) && (strcmp(quad_array[i].A2,quad_array[j].R)==0) && (strcmp(quad_array[j].A2,"-")==0))
					{
						char* ns=(char*)malloc(20);

						//for this to work, we need to find a number n such that 2^n = second argument
						int n = pow2(atoi(quad_array[j].A1));

						if(n>0)
						{
							//a >> b = a / 2^b
							/* ex- 40 / 8
							= 40 >> 3 (n=3)
							*/
							quad_array[i].Op=">>";
							sprintf(ns, "%d", n);
							strcpy(quad_array[i].A2,ns);
						}
					}
				}
			}
		}
		printQuads("after Strength Reduction");
	}

	//*******************************************************

/* has bugs
	void commonSubexprElim()
	{
		int i = 0, j = 0;
		
			
			for(i=0; i<qIndex; i++)
			{
				//for each quad (quad_i), iterate through all quads (quad_j) that come after it
				for(j=i+1; j<qIndex; j++)
				{
				
					//if both arguments of both quads match
					//and if operators of both quads match
					//and if the operator isn't any of the following
					if((strcmp(quad_array[i].A1, quad_array[j].A1)==0) && (strcmp(quad_array[i].A2, quad_array[j].A2)==0) && (strcmp(quad_array[i].Op, quad_array[j].Op)==0) && (strcmp(quad_array[i].Op, "Label")!=0) && (strcmp(quad_array[i].Op, "import")!=0) && (strcmp(quad_array[i].Op, "BeginF")!=0) && (strcmp(quad_array[i].Op, "call")!=0) && (strcmp(quad_array[i].Op, "goto")!=0) && (strcmp(quad_array[i].Op, "If False")!=0))
					{
						//if first argument of quad_i is an integer value
						//and if second argument of quad_i is blank
						//(simple assignment, ex- a=40)
						if((atoi(quad_array[i].A1)!=0) && (strcmp(quad_array[i].A2, "-")==0))
						{
							//checking to see if the results of the quads are the same. If they aren't, the value of a common variable must've changes sometime between these two statements. Therefore, they are two different quads, and neither can be eliminated
							if(strcmp(quad_array[i].R, quad_array[j].R)!=0)
							{
							
							}
							
							//if the results are the same, we can mark the second quad as redundant
							else
							{
								quad_array[j].I = -1;
							}
						}
						
					}
				}
			}
			printQuads("after Common Subexpression Elimination");
	}
*/


	//*******************************************************


	void constantPropagation()
	{
		//iterate through the quads
		for(int i=0; i<qIndex; i++)
		{	
			//if there's a quad with only one argument (second argument is blank)
			//the first argument (RHS) is an integer number (constant)
			//call this quad_i
			//ex- a=10		
			if(strcmp(quad_array[i].A2,"-")==0 && (atoi(quad_array[i].A1)!=0))
			{
				//iterating through all the quads after quad_i
				for(int j=i+1; j<qIndex; j++)
				{
					//if result (LHS) of quad_i is the first argument (RHS) of quad_j
					//and if the first argument (RHS) is not an integer (it's an identifier) 
					/*ex- 
					a=10  #quad_i
					---
					b=a+20  #quad_j
					*/
					if((strcmp(quad_array[i].R, quad_array[j].A1)==0) && (atoi(quad_array[j].A1)==0) )
					{	
						//replace the first argument of quad_j with the RHS of quad_i
						/*ex- 
						a=10  #quad_i
						---
						b=10+20  #quad_j
						*/
						strcpy(quad_array[j].A1,quad_array[i].A1);
					}
					
					//if result (LHS) of quad_i is the second argument (RHS) of quad_j
					//and if the second argument (RHS) is not an integer (it's an identifier) 
					/*ex- 
					a=10  #quad_i
					---
					b=20+a  #quad_j
					*/
					if((strcmp(quad_array[i].R, quad_array[j].A2)==0) && (atoi(quad_array[j].A2)==0) )
					{
						//replace the second argument of quad_j with the RHS of quad_i
						/*ex- 
						a=10  #quad_i
						---
						b=20+10  #quad_j
						*/
						strcpy(quad_array[j].A2,quad_array[i].A1);
					}
				}
			}
			//constant folding can be applied after this
		}
		printQuads("after Constant Propagation");
	}


	//*******************************************************

	
	void constantFolding()
	{
		//iterate through the quads
		for(int i=0; i<qIndex; i++)
		{	
			//if quad has two arguments (second argument is not blank)
			//and both arguments are integers (atoi gives 0 if the string is not a number)			
			if(strcmp(quad_array[i].A2,"-")!=0 && (atoi(quad_array[i].A1)!=0) && (atoi(quad_array[i].A2)!=0))
			{
				
				char* l=(char*)malloc(100); //holds the left operand
				char* r=(char*)malloc(100); //holds the right operand
				//int a=0,b=0;
				
				
				int res=0;
				strcpy(l,quad_array[i].A1);
				strcpy(r,quad_array[i].A2);
				
				//based on the operator, compute the expression, thereby finishing the computing at compile-time instead of runtime
				//store result in the same quad (this quad will now have only one argument, which is the computed value, and the operator will be a simple assignment)
				
				if(strcmp(quad_array[i].Op,"*")==0)
				{	
					res= atoi(l) * atoi(r); 
					char* res_str=(char*)malloc(100);
					sprintf(res_str, "%d", res);
					
					quad_array[i].A1=res_str;
					quad_array[i].A2="-";
					quad_array[i].Op="=";
				}
				
				else if(strcmp(quad_array[i].Op,"+")==0)
				{	
					res= atoi(l) + atoi(r); 
					char* res_str=(char*)malloc(100);
					sprintf(res_str, "%d", res);
					
					quad_array[i].A1=res_str;
					quad_array[i].A2="-";
					quad_array[i].Op="=";
				}
				
				else if(strcmp(quad_array[i].Op,"/")==0)
				{	
					res= atoi(l) / atoi(r); 
					char* res_str=(char*)malloc(100);
					sprintf(res_str, "%d", res);
					
					quad_array[i].A1=res_str;
					quad_array[i].A2="-";
					quad_array[i].Op="=";
					
				}
				
				else if(strcmp(quad_array[i].Op,"<<")==0)
				{	
					//int res1= (atoi(l)<<atoi(quad_array[i].A2));
					int res1= (atoi(l)<<atoi(r)); 
					char* res_str=(char*)malloc(100);
					sprintf(res_str, "%d", res1);
					
					quad_array[i].A1=res_str;
					quad_array[i].A2="-";
					quad_array[i].Op="=";
					
				}
				
				else if(strcmp(quad_array[i].Op,">>")==0)
				{	
					//int res1= (atoi(l)>>atoi(quad_array[i].A2));
					int res1= (atoi(l)>>atoi(r)); 
					char* res_str=(char*)malloc(100);
					sprintf(res_str, "%d", res1);
					
					quad_array[i].A1=res_str;
					quad_array[i].A2="-";
					quad_array[i].Op="=";
					
				}			
			}
			
			else
			{
				continue;
			}
		
		}
		printQuads("after Constant Folding");
	}
	
	
	//*******************************************************
	
	//checks to see if there exists an identifier which is not used (on the RHS of some other statement) after initial definition/assignment
	//if so, it is dead code, and its quad (the assignment quad) can be marked as redundant
	int deadCodeElimination()
	{
		int i = 0, j = 0, flag = 1, XF=0;
		while(flag==1)
		{
			flag=0;
			
			//iterate through the quads
			for(i=0; i<qIndex; i++)
			{
				XF=0;
				
				//if none of these conditions are true
				//(result should not be empty, and the operator should not be any of "Call", "Label", "goto", "If False")
				if(!((strcmp(quad_array[i].R, "-")==0) || (strcmp(quad_array[i].Op, "Call")==0) || (strcmp(quad_array[i].Op, "Label")==0) || (strcmp(quad_array[i].Op, "goto")==0) || (strcmp(quad_array[i].Op, "If False")==0)))
				{
					for(j=0; j<qIndex; j++)
					{
						//for this quad_i, for each quad_j, check to see if quad_i's result matches either of the LHS arguments of quad_j
						//(if the identifier in quad_i is used in the LHS of any other quad)
						if(((strcmp(quad_array[i].R, quad_array[j].A1)==0) && (quad_array[j].I!=-1)) || ((strcmp(quad_array[i].R, quad_array[j].A2)==0) && (quad_array[j].I!=-1)))
							{
								XF=1;
								break;
							}
					}

					//if XF = 0, => previous if was never entered, which means that for all the quads (quad_js) matched against quad_i, none of them used the identifier in quad_i. Therefore, this identifier was defined, but never used.
					//Therefore, that quad_i can be marked as redundant
					if((XF==0) && (quad_array[i].I != -1))
					{
						quad_array[i].I = -1;
						flag=1;  //therefore, continue with next quad_i
					}
				}
			}
		}
		return flag;
	}

	//*******************************************************
	
	
	void optimization()
	{
		//Calling all optimization functions
		
		strengthReduction();
		//commonSubexprElim();
		constantPropagation();
		constantFolding();
		deadCodeElimination();

		printQuads("after Dead Code Elimination");
		printf("\n");
		fprintf(fquads,"-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------\n");
	}
	
	

	
	/* ------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
	
	//prints all the STs (from all the scopes)
	void printSymbolTables()
	{
		int i = 0, j = 0;
		
		
		fprintf(fsym,"\n----------------------------------------------------------------------Symbol Table-----------------------------------------------------------------------\n");
		
		fprintf(fsym,"\n%-35s%-35s%-35s%-35s%-35s%-20s\n\n","Scope","Name","Data Type","Type","Declaration","Last Used Line");
		
		//printf("\n----------------------------Symbol Table----------------------------");
		//printf("\nScope\t\t\tName\t\t\tData Type\t\t\tType\t\t\tDeclaration\t\t\tLast Used Line\n");
		for(i=0; i<=sIndex; i++)
		{
			for(j=0; j<symbolTables[i].noOfElements; j++)
			{
				//changed printf("(%d, %d)\t\t\t%s\t\t\t%s\t\t\t%d\t\t\t%d\n", symbolTables[i].Parent, symbolTables[i].STscope, symbolTables[i].Elements[j].name, symbolTables[i].Elements[j].type, symbolTables[i].Elements[j].lineno_declared,  symbolTables[i].Elements[j].lastUseLine);
				
				//added
				//printf(" %d\t\t\t%s\t\t\t%s\t\t\t%d\t\t\t%d\n", symbolTables[i].STscope, symbolTables[i].Elements[j].name, symbolTables[i].Elements[j].datatype, symbolTables[i].Elements[j].type, symbolTables[i].Elements[j].lineno_declared,  symbolTables[i].Elements[j].lastUseLine);
				
				fprintf(fsym,"%-35d%-35s%-35s%-35s%-35d%-20d\n", symbolTables[i].STscope, symbolTables[i].Elements[j].name, symbolTables[i].Elements[j].datatype, symbolTables[i].Elements[j].type, symbolTables[i].Elements[j].lineno_declared,  symbolTables[i].Elements[j].lastUseLine); 
				
				
			}
		}
		
		//printf("-------------------------------------------------------------------------\n");
		
	}
	
	
	void printQuads(char *text)
	{
		fprintf(fquads,"-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------\n");
		fprintf(fquads,"\n---------------------------------------------------------------Quadruples %s----------------------------------------------------------------------------\n",text);
		fprintf(fquads,"\n%-35s%-35s%-35s%-35s%-35s\n\n","Lno.","Oper.","Arg1","Arg2","Res");
		
		//printf("-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------\n");
		//printf("\n-------------------------------------------------------------------------Quadruples %s--------------------------------------------------------------------------------------\n",text);
		//printf("\n%-35s%-35s%-35s%-35s%-35s\n\n","Lno.","Oper.","Arg1","Arg2","Res");

		int i = 0;
		for(i=0; i<qIndex; i++)
		{
			if(quad_array[i].I > -1)
				fprintf(fquads,"%-35d%-35s%-35s%-35s%-35s\n", quad_array[i].I, quad_array[i].Op, quad_array[i].A1, quad_array[i].A2, quad_array[i].R);
				
				//printf("%-35d%-35s%-35s%-35s%-35s\n", quad_array[i].I, quad_array[i].Op, quad_array[i].A1, quad_array[i].A2, quad_array[i].R);
		}
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
		free(quad_array);
	}
%}


//can use identifiers from lex
%union { char *text; int level; struct ASTNode* Node;};

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

//tells parser to expect exactly two conflicts (dangling elif/else)
%expect 2



//%<type> identifies the type of nonterminals. Type-checking is performed when this construct is present.
%type<Node> RunCompiler args start_block block end_block func_call call_args StartParse finalStatements arith_exp bool_exp term constant basic_stmt cmpd_stmt func_def list_index import_stmt break_stmt pass_stmt print_stmt for_stmt if_stmt elif_stmts else_stmt return_stmt assign_stmt bool_term bool_factor


%%

RunCompiler : {init();} StartParse T_EndOfFile {ftac=fopen("TAC.txt","w"); fquads=fopen("Quads.txt","w"); fsym=fopen("SymbolTable.txt","w"); printf("\n-------------------------------------------------------------------------------------------------------------------------------------------------\nValid Python Syntax!\n-------------------------------------------------------------------------------------------------------------------------------------------------\n"); fprintf(ftac,"-------------------------------------------------------------Three Address Code--------------------------------------------------------------\n");  genCode($2); printQuads(""); printSymbolTables(); optimization(); freeAll(); exit(0);} ;



StartParse : T_NL StartParse {$$=$2;}| finalStatements T_NL {resetDepth();} StartParse {$$ = pushOp("NewLine", 2, $1, $4);}| finalStatements T_NL {$$=$1;};


constant : T_Number {insertEntry("Constant", $<text>1, "int", @1.first_line, currentScope); strcpy(g_dataType, "int");  $$ = pushID_Const("Constant", $<text>1, currentScope);}
         | T_String {insertEntry("Constant", $<text>1, "str", @1.first_line, currentScope); strcpy(g_dataType, "str"); $$ = pushID_Const("Constant", $<text>1, currentScope); };
        /* | T_True {insertEntry("Constant", "True", "bool", @1.first_line, currentScope); strcpy(g_dataType, "bool"); $$ = pushID_Const("Constant", "True", currentScope);}
         | T_False {insertEntry("Constant", "False", "bool", @1.first_line, currentScope); strcpy(g_dataType, "bool"); $$ = pushID_Const("Constant", "False", currentScope);}; */
         

term : T_ID {record *element = modifyRecordID("Identifier", $<text>1, @1.first_line, currentScope); strcpy(g_dataType, element->datatype); $$ = pushID_Const("Identifier", $<text>1, currentScope);} 
     | constant {$$ = $1;}
     | list_index {$$ = $1;};


list_index : T_ID T_OSB constant T_CSB {checkIfList($<text>1, @1.first_line, currentScope); $$ = pushOp("ListIndex", 2, pushID_Const("ListTypeID", $<text>1, currentScope), $3);};


basic_stmt : pass_stmt {$$=$1;}
           | break_stmt {$$=$1;}
           | import_stmt {$$=$1;}
           | assign_stmt {$$=$1;}
           | arith_exp {$$=$1;}
           | bool_exp {$$=$1;}
           | print_stmt {$$=$1;}
           | return_stmt {$$=$1;};
           
pass_stmt : T_Pass {$$ = pushOp("pass", 0);};

break_stmt : T_Break {$$ = pushOp("break", 0);};

import_stmt : T_Import T_ID {insertEntry("ModuleName", $<text>2, "N/A", @2.first_line, currentScope); $$ = pushOp("import", 1, pushID_Const("ModuleName", $<text>2, currentScope));};

assign_stmt : T_ID T_Assign arith_exp { if(!strlen(g_dataType)) { strcpy(g_dataType, "int"); } insertEntry("Identifier", $<text>1, g_dataType, @1.first_line, currentScope); strcpy(g_dataType,""); $$ = pushOp("=", 2, pushID_Const("Identifier", $<text>1, currentScope), $3);}  
            | T_ID T_Assign bool_exp {insertEntry("Identifier", $<text>1, "bool", @1.first_line, currentScope);$$ = pushOp("=", 2, pushID_Const("Identifier", $<text>1, currentScope), $3);}   
            | T_ID  T_Assign func_call {insertEntry("Identifier", $<text>1, "unknown return", @1.first_line, currentScope); $$ = pushOp("=", 2, pushID_Const("Identifier", $<text>1, currentScope), $3);} 
            | T_ID T_Assign T_OSB T_CSB {insertEntry("ListIdentifier", $<text>1, "list", @1.first_line, currentScope); $$ = pushID_Const("ListIdentifier", $<text>1, currentScope);} ;

arith_exp : term {$$=$1;}
          | arith_exp  T_Plus  arith_exp {$$ = pushOp("+", 2, $1, $3);}
          | arith_exp  T_Minus  arith_exp {$$ = pushOp("-", 2, $1, $3);}
          | arith_exp  T_Mult  arith_exp {$$ = pushOp("*", 2, $1, $3);}
          | arith_exp  T_Div  arith_exp {$$ = pushOp("/", 2, $1, $3);}
          | T_Minus arith_exp {$$ = pushOp("-", 1, $2);}
          | T_OP arith_exp T_CP {$$ = $2;} ;
		    

bool_exp : bool_term T_Or bool_term {$$ = pushOp("or", 2, $1, $3);}
         | bool_term T_And bool_term {$$ = pushOp("and", 2, $1, $3);}          
         | arith_exp T_GT arith_exp {$$ = pushOp(">", 2, $1, $3);}
         | arith_exp T_LT arith_exp {$$ = pushOp("<", 2, $1, $3);}
         | arith_exp T_GE arith_exp {$$ = pushOp(">=", 2, $1, $3);}
         | arith_exp T_LE arith_exp {$$ = pushOp("<=", 2, $1, $3);}
         | arith_exp T_EQ arith_exp {$$ = pushOp("==", 2, $1, $3);}
         | arith_exp T_In T_ID {checkIfList($<text>3, @3.first_line, currentScope); $$ = pushOp("in", 2, $1, pushID_Const("Constant", $<text>3, currentScope));}
         | bool_term {$$=$1;};

bool_term : bool_factor {$$ = $1;} 
          //| arith_exp T_EQ arith_exp {$$ = pushOp("==", 2, $1, $3);}
          | T_True {insertEntry("Constant", "True", "bool", @1.first_line, currentScope); $$ = pushID_Const("Constant", "True", currentScope);}
          | T_False {insertEntry("Constant", "False", "bool", @1.first_line, currentScope); $$ = pushID_Const("Constant", "False", currentScope);};
          
bool_factor : T_Not bool_factor {$$ = pushOp("!", 1, $2);}
            | T_OP bool_exp T_CP {$$ = $2;};
            

print_stmt : T_Print T_OP call_args T_CP {$$ = pushOp("Print", 1, $3);};


return_stmt : T_Return {$$ = pushOp("return", 0);};

	     

finalStatements : basic_stmt {$$ = $1;}
                | cmpd_stmt {$$ = $1;}
                | func_def {$$ = $1;}
                | func_call {$$ = $1;}
                | error T_NL {yyerrok; yyclearin; $$=pushOp("SyntaxError", 0);}; //yyerrok is a mechanism that can force the parser to believe that error recovery has been accomplished. 
							//The statement: yyerrok ; in an action resets the parser to its normal mode.
							/*After an Error action, the parser restores the lookahead symbol to the value it had at the time the error was detected. 
							However, this is sometimes undesirable.
							If you want the parser to throw away the old lookahead symbol after an error, use yyclearin*/

cmpd_stmt : if_stmt {$$ = $1;}
          | for_stmt {$$ = $1;};





//this will provide 2 shift/reduce conflicts. One for elif, one for else.
/*this can be ignored as the default action of yacc in a s/r conflict is to shift
(so that the elif/else if associated with the closer if), which is what we need*/
if_stmt : T_If bool_exp T_Colon start_block {$$ = pushOp("If", 2, $2, $4);}	
        | T_If bool_exp T_Colon start_block elif_stmts {$$ = pushOp("If", 3, $2, $4, $5);};
        
elif_stmts : else_stmt {$$= $1;}
           | T_Elif bool_exp T_Colon start_block elif_stmts {$$= pushOp("Elif", 3, $2, $4, $5);};
           
else_stmt : T_Else T_Colon start_block {$$ = pushOp("Else", 1, $3);};




/*
iterable: T_ID {checkIfList($<text>1, @1.first_line, currentScope);}
	| T_Range T_OP T_Number T_Comma T_Number T_CP ;

for_stmt : T_For T_ID T_In iterable T_Colon start_block {insertEntry("Identifier", $<text>2, @2.first_line, currentScope); };
*/


for_stmt : T_For T_ID T_In T_Range T_OP term T_Comma term T_CP T_Colon start_block {
	insertEntry("Identifier", $<text>2, "int", @1.first_line, currentScope); 
	Node* idNode = pushID_Const("Identifier", $<text>2, currentScope); 
	e1 = pushOp("=", 2, idNode, $<text>6); 
	e2 = pushOp(">=", 2, idNode, $<text>6); 
	e3 = pushOp("<", 2, idNode, $<text>8); 
	$$ = pushOp("For", 4, e1, e2, e3, $11);
	}
	| T_For T_ID T_In T_ID {checkIfList($<text>4, @1.first_line, currentScope);} T_Colon start_block {insertEntry("Identifier", $<text>2, "int", @1.first_line, currentScope); }; 




start_block : basic_stmt {$$ = $1;}
            | T_NL T_INDENT {
				if(scopeChange) {
					initNewTable(currentScope+1); 
					currentScope++; 
				}
			     }  finalStatements block {$$ = pushOp("StartBlock", 2, $4, $5);};

block : T_NL T_ND finalStatements block {$$ = pushOp("Next", 2, $3, $4);}
      | T_NL end_block {$$ = $2;};

end_block : T_DEDENT {if(scopeChange) 
			{ currentScope--; 
			  scopeChange-- ;}  } finalStatements {$$ = pushOp("EndBlock", 1, $3);}
          | T_DEDENT { if(scopeChange) 
          		{ currentScope--; 
          		  scopeChange-- ;} } {$$ = pushOp("EndBlock", 0);}
          | { if(scopeChange) {currentScope--; scopeChange-- ;} $$ = pushOp("EndBlock", 0); resetDepth();};

args : T_ID {addToList($<text>1, 1);} args_list {$$ = pushOp(argsList, 0); clearArgsList();}
     | {$$ = pushOp("Void", 0);};

args_list : T_Comma T_ID {addToList($<text>2, 0);} args_list | ;


call_list : T_Comma term {addToList($<text>1, 0);} call_list | ;

call_args : T_ID {addToList($<text>1, 1);} call_list {$$ = pushOp(argsList, 0); clearArgsList();}
	| T_Number {addToList($<text>1, 1);} call_list {$$ = pushOp(argsList, 0); clearArgsList();}
	| T_String {addToList($<text>1, 1);} call_list {$$ = pushOp(argsList, 0); clearArgsList();}	
	| {$$ = pushOp("Void", 0);};

func_def : T_Def T_ID {insertEntry("Func_Name", $<text>2, "func", @2.first_line, currentScope); scopeChange++ ; } T_OP args T_CP T_Colon start_block { $$ = pushOp("Func_Name", 3, pushID_Const("Func_Name", $<text>2, currentScope), $5, $8);};

func_call : T_ID T_OP call_args T_CP {$$ = pushOp("Func_Call", 2, pushID_Const("Func_Name", $<text>1, currentScope), $3);};

 
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

