//
//  bridge.h
//  loclog
//
//  Created by Garrett Mohammadioun on 5/25/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

#ifndef bridge_h
#define bridge_h

#include <stdio.h>
#include <stdlib.h>
#include "../libpq.framework/Versions/A/Headers/libpq-fe.h"

int exec_query(const char *query);

#endif /* bridge_h */
