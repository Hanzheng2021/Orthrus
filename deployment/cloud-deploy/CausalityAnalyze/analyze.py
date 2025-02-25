import os
import sys
import re
import numpy as np


def cast_time(time_str):
    res=0
    res+=int(time_str[11:13])*60*60*1000
    res+=int(time_str[14:16])*60*1000
    res+=int(time_str[17:19])*1000
    res+=int(time_str[20:23])
    return res

def merge_sort(data):
    if len(data) <= 1:
        return data
    index = len(data) // 2
    lst1 = data[:index]
    lst2 = data[index:]
    left = merge_sort(lst1)
    right = merge_sort(lst2)
    return merge(left, right)


def merge(lst1, lst2):
    """to Merge two list together"""
    list = []
    while len(lst1) > 0 and len(lst2) > 0:
        data1 = lst1[0]
        data2 = lst2[0]
        if data1[0] <= data2[0]:
            list.append(lst1.pop(0))
        else:
            global reverse_pair
            global sn_deliver_sorted
            global g
            if (abs(sn_deliver_sorted[data1[1]]-sn_deliver_sorted[data2[1]])>=g):
                reverse_pair.append((data1[1],data2[1]))

            list.append(lst2.pop(0))
    if len(lst1) > 0:
        list.extend(lst1)
    else:
        list.extend(lst2)
    return list


if __name__=='__main__':
    sys.stdout = open('CausalityAnalyze/output.log','w')
 
    # print(cast_time('2023/07/11 00:00:00.00000'))
    # print(cast_time('2023/07/11 01:00:00.00000'))
    # print(cast_time('2023/07/11 00:01:00.00000'))
    # print(cast_time('2023/07/11 00:00:01.00000'))
    # print(cast_time('2023/07/11 00:00:00.10000'))
    # print(cast_time('2023/07/11 00:00:00.01000'))
    # print(cast_time('2023/07/11 00:00:00.00100'))
    # print(cast_time('2023/07/11 00:00:00.00010'))
    # sys.exit()

    experiment_names=[]
    for dirPath, dirNames, fileNames in os.walk(sys.argv[1]):
        # print(dirNames)
        # print(dirPath, dirNames, fileNames)
        experiment_names=dirNames
        break
    # print('============')
    # sys.exit()

    for name in experiment_names:
        print('---------------------------------------')
        print(name)
        name_='fairness_res_'+name
        experiment_nums=[]
        dirP=''
        fileNs=[]
        for dirPath, dirNames, fileNames in os.walk(sys.argv[1]+'/'+name+'/log/'):
            # print('============')
            # print(dirNames)
            # print(dirPath, dirNames, fileNames)
            dirP=dirPath
            fileNs=fileNames
            experiment_nums=dirNames
            break
        peer_dir=[]
        for num in fileNs:

            path=dirP+num
            peer_dir.append(path)
            # print(path)
            continue
            
            g=0.0
            # if len(sys.argv)>=3:
            #     g=float(sys.argv[2])

                        # client_dir.append(path+'/'+d+'/client-'+str_format.format(an=0)+'.log')

        # print(peer_dir)

        req_submit={}
        req_finish={}

        # sn_to_req={}
        sn_propose={}
        sn_commit={}
        sn_deliver={}
        sn_enoughHtn={}
        originsn_to_sn={}
        req_to_sn={}

        valid_sn=set()


        for i in peer_dir:
            f = open(i)
            # print(i)
            lines = f.readlines()
            pattern_propose=r'sendPreprepare replica \d+: PREPREPARE '
            pattern_commit=r'handleCommit COMMITTED \d+ with'
            pattern_deliver=r'deliverBatch DELIVERING \d+ with'
            pattern_enough_htn=r'Set TRUE.'
            pattern_sn=r'sn=\d+'
            pattern_req_id=r'req_id is: \[[\d ]*\]'

            peer_id=-1
            for line in lines:
                find_=re.search(pattern_propose,line)
                if find_ is not None:
                    # print('PREPREPARE sn = '+str((line[find_.span()[1]:].strip())))
                    sn_propose[int(line[find_.span()[1]:].strip())]=cast_time(line)

                find_=re.search(pattern_commit,line)
                if find_ is not None:
                    # print(find_)
                    sn=int(line[find_.span()[0]+23:find_.span()[1]-5])
                    if sn not in sn_commit:
                        sn_commit[sn]=[cast_time(line)]
                    else:
                        # print('COMMITTED sn is '+str(sn))
                        sn_commit[sn].append(cast_time(line))   

                find_=re.search(pattern_deliver,line)
                if find_ is not None:
                    # print(find_)
                    sn=int(line[find_.span()[0]+24:find_.span()[1]-5])
                    if sn not in sn_deliver:
                        sn_deliver[sn]=[cast_time(line)]
                    else:
                        # print('DELIVERED sn is '+str(sn))
                        sn_deliver[sn].append(cast_time(line)) 

                find_=re.search(pattern_enough_htn,line)
                if find_ is not None:
                    # print(find_)
                    find_sn=re.search(r'sn=\d+',line)
                    sn=int(line[find_sn.span()[0]+3:find_sn.span()[1]])-len(peer_dir)
                    if sn not in sn_enoughHtn:
                        sn_enoughHtn[sn]=cast_time(line)

                find_=re.search(pattern_req_id,line)
                if find_ is not None:
                    # print(line)
                    # print(find_.span())
                    num_str=line[find_.span()[0]+12:find_.span()[1]-1]
                    # print(num_str)

                    find_sn=re.search(r'Sn=\d+',line)
                    sn=int(line[find_sn.span()[0]+3:find_sn.span()[1]])
                    # print(sn)
                    valid_sn.add(sn)
                    for i in num_str.split(" "):
                        # print(i)
                        req_to_sn[int(i)]=sn


        # print('------------------------------------')
        # print(originsn_to_sn)
        # print('------------------------------------')
        # print(sn_propose)
        # print(len(sn_propose))
        # print('------------------------------------')
        # print(sn_commit)
        # print(len(sn_commit))
        # print('------------------------------------')
        # print(sn_deliver)
        # print(len(sn_deliver))
        # print('------------------------------------')
        # print(sn_enoughHtn)
        # print(len(sn_enoughHtn))
        # print('------------------------------------')

        submit_ls=[]
        propose_ls=[]
        commit_ls=[]
        deliver_ls=[]

        # print(sn_deliver)
        print('batch length is '+str(len(sn_deliver)))

        quorum=int((len(peer_dir)-1)/3) * 2 + 1
        # print(quorum)

        sn_commit_quorum={}
        for key in sn_commit:
            if len(sn_commit[key]) < quorum:
                sn_commit_quorum[key]=sorted(sn_commit[key],reverse=True)[0]
            else:
                sn_commit_quorum[key]=sorted(sn_commit[key])[quorum-1]

        sn_commit_quorum_sorted=dict(sorted(sn_commit_quorum.items(), key=lambda item: item[0]))
        # print(sn_commit_quorum_sorted)


        sn_deliver_mean= {}
        for item in sn_deliver.keys():
            sn_deliver_mean[item]=np.array(sn_deliver[item]).mean()
        sn_deliver_sorted=dict(sorted(sn_deliver_mean.items(), key=lambda item: item[1]))
        # print('------------------------------------')


        #   Redirect output to file
        # origin_stdout = sys.stdout
        # sys.stdout = open('scripts/cloud-deploy/Fairness_data_process/output.log','a')
    
        sn_info={}
        for i in sn_propose:
            if i in sn_propose and i in sn_commit_quorum and i in sn_deliver_mean:
                start = sn_propose[i]
                enoughHtnTime = 0
                if len(sn_enoughHtn) != 0 and i not in sn_enoughHtn:
                    continue
                elif len(sn_enoughHtn) != 0:
                    enoughHtnTime = sn_enoughHtn[i]-start
                sn_info[i] = {'batchNo':i,'propose':start,'commit':sn_commit_quorum[i]-start,'deliver':sn_deliver_mean[i]-start,'sn_enoughHtn':enoughHtnTime}

        N=0
        n=len(sn_propose)
        NSet=[]
        for i in sn_commit_quorum:
            for j in range(i):
                if j in sn_propose and sn_propose[j]>sn_commit_quorum[i]:
                    N+=1
                    NSet.append((i,j))
        print('N: '+str(N))
        print('n: '+str(n))
        print('C: '+str(1-2*N/(n*(n-1))))

        sn_propose2commit=[]
        sn_propose2deliver=[]
        sn_commit2deliver=[]
        sn_propose2enoughHtn=[]

        for i in sn_info:
            sn_propose2commit.append(sn_info[i]['commit'])
            sn_propose2deliver.append(sn_info[i]['deliver'])
            sn_commit2deliver.append(sn_info[i]['deliver']-sn_info[i]['commit'])
            if len(sn_enoughHtn) != 0:
                sn_propose2enoughHtn.append(sn_info[i]['sn_enoughHtn'])

        # print(sn_propose2commit)
        # print(sn_propose2deliver)
        # print(sn_commit2deliver)
        # print(sn_propose2enoughHtn)
    
        print('============================')
        print('Propose-2f+1Commit: '+str(np.array(sn_propose2commit).mean()))
        print('Propose-EnoughHtn: '+str(np.array(sn_propose2enoughHtn).mean()))
        print('Commit-Deliver: '+str(np.array(sn_commit2deliver).mean()))
        print('Propose-Deliver: '+str(np.array(sn_propose2deliver).mean()))
        print('============================')

        # for line in sn_info.items():
        #     print(line[1])

        # sys.stdout = origin_stdout