import os
import sys
import re
import numpy as np


def cast_time(time_str):
    res=0
    res+=int(time_str[0:2])*60*60*1000
    res+=int(time_str[3:5])*60*1000
    res+=int(time_str[6:8])*1000
    res+=int(time_str[9:12])
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
    sys.stdout = open('scripts/cloud-deploy/Fairness_data_process/output.log','a')
 
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
        name_='fairness_res_'+name
        experiment_nums=[]
        dirP=''
        for dirPath, dirNames, fileNames in os.walk(sys.argv[1]+'/'+name+'/experiment-output/'):
            # print('============')
            # print(dirNames)
            # print(dirPath, dirNames, fileNames)
            dirP=dirPath
            experiment_nums=dirNames
            break
        for num in experiment_nums:

            path=dirP+num
            
            print(path)
            # continue
            
            g=0.0
            # if len(sys.argv)>=3:
            #     g=float(sys.argv[2])

            dir = os.listdir(path)
            peer_dir=[]
            client_dir=[]
            for d in dir:
                if re.match('slave',d) is not None:
                    dir_temp=path+'/'+d
                    # print(dir_temp)
                    is_client=False
                    for content in os.listdir(dir_temp):
                        if re.match('client',content):
                            is_client=True
                    if is_client==False:
                        peer_dir.append(path+'/'+d+'/peer.log')
                    else:
                        # print(d)
                        cli_dir = os.listdir(path+'/'+d)
                        for cli in cli_dir:
                            if re.match('client-\d+\.log',cli):
                                # print(cli)
                                client_dir.append(path+'/'+d+'/'+cli)

                        # str_format="{an:03d}"
                        # # print(str_format.format(an=len(client_dir)))
                        # # client_dir.append(path+'/'+d+'/client-'+str_format.format(an=len(client_dir))+'.log')
                        # print(path+'/'+d+'/client-'+str_format.format(an=0)+'.log')
                        # client_dir.append(path+'/'+d+'/client-'+str_format.format(an=0)+'.log')

            # print('Client Num: '+str(len(client_dir)))
            # print('Peer Num: '+str(len(peer_dir)))
            req_submit={}
            req_finish={}

            # print('client_dir is ')
            # print(client_dir)
            # load submit request time in client.
            for i in client_dir:
                f = open(i)
                lines = f.readlines()
                # print(lines)
                pattern_finish=r'Request finished \(out of order\)\. clSeqNr='
                pattern=r'Submitted request. clSeqNr='
                for line in lines:
                    # print(line)
                    find_=re.search(pattern,line)
                    # print(find_)
                    if find_ is not None:
                        # print('============')
                        req_num=int(line[find_.span()[1]:].strip('\n'))
                        req_submit[req_num]=cast_time(line[:12])
                        # print(req_num,req_submit)
                    find_=re.search(pattern_finish,line)
                    # print(find_)
                    if find_ is not None:
                        req_num=int(line[find_.span()[1]:].strip('\n'))
                        req_finish[req_num]=cast_time(line[:12])
                        # print(req_num,req_finish)

                f.close()

            # print('req_submit info: ')
            # print(req_submit)

            # print('req_finish info: ')
            # print(req_finish)

            # sn_to_req={}
            originsn_propose={}
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
                pattern_propose=r'Sending PREPREPARE. nReq=\d+'
                pattern_commit=r'Get logEntry.Sn from tn'
                pattern_deliver=r'Delivered batch.'
                pattern_enough_htn=r'Set TRUE.'
                pattern_sn=r'sn=\d+'
                pattern_req_id=r'req_id is: \[[\d ]*\]'

                peer_id=-1
                for line in lines:
                    find_=re.search(pattern_propose,line)
                    if find_ is not None:
                        if peer_id==-1:
                            find_peerID=re.search(r'Sending PREPREPARE. nReq=\d+ senderID=',line)
                            peer_id=int(line[find_peerID.span()[1]])
                            # sn_to_req[peer_id]=[]
                            # print('peer_id is '+str(peer_id))
                        # print(find_)
                        find_sn=re.search(pattern_sn,line)
                        # sn_to_req[peer_id].append((int(line[42:find_.span()[1]]),int(line[find_sn.span()[0]+3:find_sn.span()[1]])))
                        originsn_propose[int(line[find_sn.span()[0]+3:find_sn.span()[1]])]=cast_time(line)

                    find_=re.search(pattern_commit,line)
                    if find_ is not None:
                        # print(find_)
                        find_sn=re.search(r'Sn=\d+',line)
                        if find_sn is None:
                            continue
                        sn=int(line[find_sn.span()[0]+3:find_sn.span()[1]])
                        if sn not in sn_commit:
                            sn_commit[sn]=[cast_time(line)]
                        else:
                            sn_commit[sn].append(cast_time(line))   

                        find_originsn=re.search(r'origin\_sn=\d+',line)
                        if find_originsn is not None:
                            originsn=int(line[find_originsn.span()[0]+10:find_originsn.span()[1]])
                            originsn_to_sn[originsn]=sn

                    find_=re.search(pattern_deliver,line)
                    if find_ is not None:
                        # print(find_)
                        find_sn=re.search(pattern_sn,line)
                        sn=int(line[find_sn.span()[0]+3:find_sn.span()[1]])
                        if sn not in sn_deliver:
                            sn_deliver[sn]=[cast_time(line)]
                        else:
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

            # print(originsn_to_sn)
            # print(sorted(originsn_to_sn.keys()))
            # print(sorted(originsn_propose.keys()))
            for key in originsn_propose.keys():
                if key in originsn_to_sn:
                    sn_propose[originsn_to_sn[key]]=originsn_propose[key]


            # print('------------------------------------')
            # print(originsn_to_sn)
            # print('------------------------------------')
            # print(originsn_propose)
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

            # ------------------------------------------------
            # sort propose, find inverse deliver.
            sn_propose_sorted= dict(sorted(sn_propose.items(), key=lambda item: item[1]))


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