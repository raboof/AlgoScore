/*
  Copyright 2003-2008 Andrew Ross
 
  This file is part of Nasal.
 
  Nasal is free software; you can redistribute it and/or
  modify it under the terms of the GNU Library General Public
  License as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.

  Nasal is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Library General Public License for more details.

  You should have received a copy of the GNU Library General Public
  License along with Nasal; if not, write to the Free
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

#ifndef _PARSE_H
#define _PARSE_H

#include <setjmp.h>

#include "nasal.h"
#include "data.h"
#include "code.h"

enum tok {
    TOK_TOP=1, TOK_AND, TOK_OR, TOK_NOT, TOK_LPAR, TOK_RPAR, TOK_LBRA,
    TOK_RBRA, TOK_LCURL, TOK_RCURL, TOK_MUL, TOK_PLUS, TOK_MINUS, TOK_NEG,
    TOK_DIV, TOK_CAT, TOK_COLON, TOK_DOT, TOK_COMMA, TOK_SEMI,
    TOK_ASSIGN, TOK_LT, TOK_LTE, TOK_EQ, TOK_NEQ, TOK_GT, TOK_GTE,
    TOK_IF, TOK_ELSIF, TOK_ELSE, TOK_FOR, TOK_FOREACH, TOK_WHILE,
    TOK_RETURN, TOK_BREAK, TOK_CONTINUE, TOK_FUNC, TOK_SYMBOL,
    TOK_LITERAL, TOK_EMPTY, TOK_NIL, TOK_ELLIPSIS, TOK_QUESTION, TOK_VAR,
    TOK_PLUSEQ, TOK_MINUSEQ, TOK_MULEQ, TOK_DIVEQ, TOK_CATEQ,
    TOK_FORINDEX
};

// Precedence rules
enum { PREC_BINARY=1, PREC_REVERSE, PREC_PREFIX, PREC_SUFFIX };

struct Token {
    enum tok type;
    int line;
    char* str;
    int strlen;
    int rule;
    double num;
    struct Token* next;
    struct Token* prev;
    struct Token* children;
    struct Token* lastChild;
};

struct Parser {
    // Handle to the Nasal interpreter
    struct Context* context;

    char* err;
    int errLine;
    jmp_buf jumpHandle;

    // The parse tree ubernode
    struct Token tree;

    // The input buffer
    char* buf;
    int   len;

    // Input file parameters (for generating pretty stack dumps)
    naRef srcFile;
    int firstLine;

    // Chunk allocator.  Throw away after parsing.
    void** chunks;
    int* chunkSizes;
    int nChunks;
    int leftInChunk;

    // Computed line number table for the lexer
    int* lines;
    int  nLines;

    struct CodeGenerator* cg;
};

struct CodeGenerator {
    int lastLine;

    // Accumulated byte code array
    unsigned short* byteCode;
    int codesz;
    int codeAlloced;

    // Inst. -> line table, stores pairs of {ip, line}
    unsigned short* lineIps;
    int nLineIps; // number of pairs
    int nextLineIp;

    int* argSyms;
    int* optArgSyms;
    int* optArgVals;
    naRef restArgSym;

    // Stack of "loop" frames for break/continue statements
    struct {
        int breakIP;
        int contIP;
        struct Token* label;
    } loops[MAX_MARK_DEPTH];
    int loopTop;

    // Dynamic storage for constants, to be compiled into a static table
    naRef consts;
};

void naParseError(struct Parser* p, char* msg, int line);
void naParseInit(struct Parser* p);
void* naParseAlloc(struct Parser* p, int bytes);
void naParseDestroy(struct Parser* p);
void naLex(struct Parser* p);
int naLexUtf8C(char* s, int len, int* used); /* in utf8lib.c */
naRef naCodeGen(struct Parser* p, struct Token* block, struct Token* arglist);

void naParse(struct Parser* p);



#endif // _PARSE_H
