import os
import sqlite3
import numpy as np

# filenames = ['eventDB.sqlite','eventDB2.sqlite','eventDB3.sqlite','eventDB4.sqlite']
filenames = ['eventDB.sqlite']


for file in filenames:
    # 创建SQLite数据库并连接
    conn = sqlite3.connect(file)
    cursor = conn.cursor()


    REQ_SEND={}
    REQ_RECEIVE={}
    REQ_PROPOSE={}
    REQ_COMMIT={}
    REQ_DELIVERED={}
    RESP_SEND={}
    ENOUGH_RESP={}

    cursor.execute('select ts,event,nodeId,clSn from request;')
    all_rows = cursor.fetchall()


    for row in all_rows:
        ts, event, nodeId, clSn = row
        # print(row)
        if event=='REQ_SEND':
            if (nodeId, clSn) in REQ_SEND:
                REQ_SEND[(nodeId, clSn)].append(int(ts))
            else:
                REQ_SEND[(nodeId, clSn)] = [int(ts)]

        if event=='REQ_RECEIVE':
            if (nodeId, clSn) in REQ_RECEIVE:
                REQ_RECEIVE[(nodeId, clSn)].append(int(ts))
            else:
                REQ_RECEIVE[(nodeId, clSn)] = [int(ts)]

        if event=='REQ_PROPOSE':
            if (nodeId, clSn) in REQ_PROPOSE:
                REQ_PROPOSE[(nodeId, clSn)].append(int(ts))
            else:
                REQ_PROPOSE[(nodeId, clSn)] = [int(ts)]

        if event=='REQ_COMMIT':
            if (nodeId, clSn) in REQ_COMMIT:
                REQ_COMMIT[(nodeId, clSn)].append(int(ts))
            else:
                REQ_COMMIT[(nodeId, clSn)] = [int(ts)]
    
        if event=='REQ_DELIVERED':
            if (nodeId, clSn) in REQ_DELIVERED:
                REQ_DELIVERED[(nodeId, clSn)].append(int(ts))
            else:
                REQ_DELIVERED[(nodeId, clSn)] = [int(ts)]

        if event=='RESP_SEND':
            if (nodeId, clSn) in RESP_SEND:
                RESP_SEND[(nodeId, clSn)].append(int(ts))
            else:
                RESP_SEND[(nodeId, clSn)] = [int(ts)]

        if event=='ENOUGH_RESP':
            if (nodeId, clSn) in ENOUGH_RESP:
                ENOUGH_RESP[(nodeId, clSn)].append(int(ts))
            else:
                ENOUGH_RESP[(nodeId, clSn)] = [int(ts)]
    
    
        # if (nodeId, clSn) in result:
        #     result[(nodeId, clSn)][event] = int(ts)


    # print('REQ_SEND')
    # print(REQ_SEND)
    # print('REQ_RECEIVE')
    # print(REQ_RECEIVE)
    # print('REQ_PROPOSE')
    # print(REQ_PROPOSE)
    # print('REQ_COMMIT')
    # print(REQ_COMMIT)
    # print('REQ_DELIVERED')
    # print(REQ_DELIVERED)
    # print('RESP_SEND')
    # print(RESP_SEND)
    # print('ENOUGH_RESP')
    # print(ENOUGH_RESP)

    cursor.execute('select distinct nodeId,clSn from request;')
    all_rows = cursor.fetchall()

    result={}
    for row in all_rows:
        (nodeId, clSn) = row
        # if (nodeId, clSn) in REQ_COMMIT and (nodeId, clSn) in REQ_DELIVERED: 
        if (nodeId, clSn) in REQ_SEND and (nodeId, clSn) in REQ_RECEIVE and (nodeId, clSn) in REQ_PROPOSE and (nodeId, clSn) in REQ_COMMIT and (nodeId, clSn) in REQ_DELIVERED and (nodeId, clSn) in RESP_SEND and (nodeId, clSn) in ENOUGH_RESP: 
            print('result insert !!!')
            result[(nodeId, clSn)] = {'REQ_SEND':0, 'REQ_RECEIVE':-1, 'REQ_PROPOSE':-1, 'REQ_COMMIT': -1, 'REQ_DELIVERED': -1, 'RESP_SEND': -1, 'ENOUGH_RESP': -1}

    for row in result:
        result[row]['ENOUGH_RESP'] = np.array(ENOUGH_RESP[row]).mean()
        result[row]['RESP_SEND'] = np.array(RESP_SEND[row]).mean()
        result[row]['REQ_DELIVERED'] = np.array(REQ_DELIVERED[row]).mean()
        result[row]['REQ_COMMIT'] = np.array(REQ_COMMIT[row]).mean()
        result[row]['REQ_PROPOSE'] = np.array(REQ_PROPOSE[row]).mean()
        result[row]['REQ_RECEIVE'] = np.array(REQ_RECEIVE[row]).mean()
        result[row]['REQ_SEND'] = np.array(REQ_SEND[row]).mean()

        result[row]['ENOUGH_RESP'] -= result[row]['RESP_SEND']
        result[row]['RESP_SEND'] -= result[row]['REQ_DELIVERED']
        result[row]['REQ_DELIVERED'] -= result[row]['REQ_COMMIT']
        result[row]['REQ_COMMIT'] -= result[row]['REQ_PROPOSE']
        result[row]['REQ_PROPOSE'] -= result[row]['REQ_RECEIVE']
        result[row]['REQ_RECEIVE'] -= result[row]['REQ_SEND']
        result[row]['REQ_SEND'] = 0

        if result[row]['RESP_SEND'] < 0:
            result[row]['RESP_SEND'] = 0
            result[row]['REQ_DELIVERED'] = 0

    # print(result)

    REQ_SEND=[]
    REQ_RECEIVE=[]
    REQ_PROPOSE=[]
    REQ_COMMIT=[]
    REQ_DELIVERED=[]
    RESP_SEND=[]
    ENOUGH_RESP=[]

    for row in result:
        REQ_SEND.append(result[row]['REQ_SEND'])
        REQ_RECEIVE.append(result[row]['REQ_RECEIVE'])
        REQ_PROPOSE.append(result[row]['REQ_PROPOSE'])
        REQ_COMMIT.append(result[row]['REQ_COMMIT'])
        REQ_DELIVERED.append(result[row]['REQ_DELIVERED'])
        RESP_SEND.append(result[row]['RESP_SEND'])
        ENOUGH_RESP.append(result[row]['ENOUGH_RESP'])

    mean_result = {'REQ_SEND':0, 'REQ_RECEIVE':-1, 'REQ_PROPOSE':-1, 'REQ_COMMIT': -1, 'REQ_DELIVERED': -1, 'RESP_SEND': -1, 'ENOUGH_RESP': -1}
    mean_result['REQ_SEND'] = 0
    mean_result['REQ_RECEIVE'] = np.array(REQ_RECEIVE).mean()
    mean_result['REQ_PROPOSE'] = np.array(REQ_PROPOSE).mean()
    mean_result['REQ_COMMIT'] = np.array(REQ_COMMIT).mean()
    mean_result['REQ_DELIVERED'] = np.array(REQ_DELIVERED).mean()
    mean_result['RESP_SEND'] = np.array(RESP_SEND).mean()
    mean_result['ENOUGH_RESP'] = np.array(ENOUGH_RESP).mean()

    print(mean_result)

    cursor.close()
    conn.close()


