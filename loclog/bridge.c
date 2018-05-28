//
//  bridge.c
//  loclog
//
//  Created by Garrett Mohammadioun on 5/25/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

#include <string.h>
#include <stdio.h>
#include "bridge.h"

char *exec_query(const char *query) {
    PGconn *connection = PQconnectdb("postgres://Garrett@garspace.com/Garrett");
    if (PQstatus(connection) != CONNECTION_OK) {
        char *error = PQerrorMessage(connection);
        char *msg = malloc(strlen(error) + 1);
        strcpy(msg, error);
        PQfinish(connection);
        return msg;
    }
    
    PGresult *result = PQexec(connection, query);
    if (PQresultStatus(result) != PGRES_COMMAND_OK) {
        //printf("query failed with error: %s", PQresultErrorMessage(result));
        char *error = PQresultErrorMessage(result);
        char *msg = malloc(strlen(error) + 1);
        strcpy(msg, error);
        PQclear(result);
        PQfinish(connection);
        return msg;
    }
    
    PQclear(result);
    PQfinish(connection);
    
    char *msg = malloc(1);
    msg[0] = '\0';
    return msg;
}
