//
//  bridge.c
//  loclog
//
//  Created by Garrett Mohammadioun on 5/25/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

#include "bridge.h"

int exec_query(const char *query) {
    PGconn *connection = PQconnectdb("postgres://Garrett@garspace.com/Garrett");
    if (PQstatus(connection) != CONNECTION_OK) {
        return -1;
    }
    
    PGresult *result = PQexec(connection, query);
    if (PQresultStatus(result) != PGRES_COMMAND_OK) {
        return -2;
    }
    
    PQclear(result);
    PQfinish(connection);
    
    return 0;
}
