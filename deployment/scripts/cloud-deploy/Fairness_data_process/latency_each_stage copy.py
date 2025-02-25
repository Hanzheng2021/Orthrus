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

    experiment_num=[]
    for dirPath, dirNames, fileNames in os.walk("scripts/cloud-deploy/Fairness_data_process/experiment-output/"):
        print(dirNames)
        print(dirPath, dirNames, fileNames)
        experiment_num=dirNames
        break
    print('-------------')
    # sys.exit()

    for num in experiment_num:
        print('-------------')
        name='fairness_res_'+num
        path='./scripts/cloud-deploy/Fairness_data_process/experiment-output/'+num
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
                            print(cli)
                            client_dir.append(path+'/'+d+'/'+cli)

                    # str_format="{an:03d}"
                    # # print(str_format.format(an=len(client_dir)))
                    # # client_dir.append(path+'/'+d+'/client-'+str_format.format(an=len(client_dir))+'.log')
                    # print(path+'/'+d+'/client-'+str_format.format(an=0)+'.log')
                    # client_dir.append(path+'/'+d+'/client-'+str_format.format(an=0)+'.log')

        print(len(client_dir))
        print(len(peer_dir))
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
        # print(req_to_sn)
        # print('------------------------------------')
        # print(valid_sn)
        # print(len(valid_sn))
        # print('------------------------------------')

        req_info={}
        for i in req_to_sn.keys():
            req_info[i]={}
            req_info[i]['sn']=req_to_sn[i]
        # print(len(req_info))

        # print('------------------------------------')
        # print('req_info')
        # print(req_info)
        # print('------------------------------------')

        submit_ls=[]
        propose_ls=[]
        commit_ls=[]
        deliver_ls=[]

        # print(sn_deliver)
        print('batch length is '+str(len(sn_deliver)))

        # for i in req_info.keys():
            # print(req_info[0])
        # print(req_submit[0])
        # print(sn_propose)
        for i in req_info.keys():
            sn=req_info[i]['sn']
            # print(sn)
            if (i in req_submit.keys()):
                base = req_submit[i]
            else:
                continue
            req_info[i]['submit']=req_submit[i]-base
            req_info[i]['propose']=sn_propose[sn]-base
            req_info[i]['commit']=np.array(sn_commit[sn]).mean()-base
            req_info[i]['deliver']=np.array(sn_deliver[sn]).mean()-base
            req_info[i]['finish']=req_finish[i]-base
            submit_ls.append(req_info[i]['submit'])
            propose_ls.append(req_info[i]['propose'])
            commit_ls.append(req_info[i]['commit'])
            deliver_ls.append(req_info[i]['deliver'])

        submit_ls_avg=np.array(submit_ls).mean()
        propose_ls_avg=np.array(propose_ls).mean()
        commit_ls_avg=np.array(commit_ls).mean()
        deliver_ls_avg=np.array(deliver_ls).mean()
        print('The average stage timecost is :')
        print('Average stage timecost: {\'submit\': '+str(submit_ls_avg)+', \'propose\': '+str(propose_ls_avg)+', \'commit\': '+str(commit_ls_avg)+', \'deliver\': '+str(deliver_ls_avg)+'}')

        # for i in range(len(req_info)):
        #     print('req_num:'+str(i)+': '+str(req_info[i]))

        # Save fairness result
        # with open(name,'w') as o:
        #     for i in range(len(req_info)):
        #         o.write('req_num_'+str(i)+': '+str(req_info[i])+'\n')

        print('------------------------------------')
        print('Stage latency analyze result have been written to '+name)
        print('------------------------------------')



        # ------------------------------------------------
        # sort propose, find inverse deliver.
        sn_propose_sorted= dict(sorted(sn_propose.items(), key=lambda item: item[1]))

        sn_deliver_mean= {}
        for item in sn_deliver.keys():
            sn_deliver_mean[item]=np.array(sn_deliver[item]).mean()
        sn_deliver_sorted=dict(sorted(sn_deliver_mean.items(), key=lambda item: item[1]))
        # print('------------------------------------')

        cnt=0
        sn_to_idx={}
        for item in sn_propose_sorted:
            sn_to_idx[item]=cnt
            cnt+=1

        # (x, y) x is index number, y is the our defined sn number.
        # print(sn_to_idx)
        judge_inv_list2=[(sn_to_idx[item],item) for item in sn_deliver_sorted]
        # for item in sn_deliver_sorted:
        #     if item in sn_to_idx:
        #         judge_inv_list2.append(sn_to_idx[item])
        # print(judge_inv_list2)


        reverse_pair=[]
        merge_sort(judge_inv_list2)
        print('With g = ' + str(g) + 'ms, there is '+str(len(reverse_pair))+' reverse pair.')
        print(reverse_pair)
        print('------------------------------------')

        frontrunning_latency=[]
        for key in sn_deliver:
            frontrunning_latency.append(np.array(sn_deliver[key]).mean()-np.array(sn_commit[key]).mean())
        frontrunning_latency_avg=np.array(frontrunning_latency).mean()
        print('The average frontrunning latency is '+str(frontrunning_latency_avg) +'ms.')
        print('------------------------------------')


        # print(sorted(sn_propose.items(), key=lambda item: item[1]))
        # print(sorted(sn_commit.items(), key=lambda item: item[1]))

        quorum=int((len(peer_dir)-1)/3) * 2 + 1
        # print(quorum)

        sn_commit_quorum={}
        for key in sn_commit:
            sn_commit_quorum[key]=sorted(sn_commit[key])[quorum-1]

        # print(sn_propose_sorted)
        # print(sn_commit_quorum)

        sn_commit_quorum_sorted=dict(sorted(sn_commit_quorum.items(), key=lambda item: item[1]))
        # print(sn_commit_quorum_sorted)

        sn_frontrunning_block_lst={}

        for key in sn_commit_quorum_sorted:
            sn_frontrunning_block_lst[key]=[]
            commit_quorum_time=sn_commit_quorum_sorted[key]
            for i in range(key):
                if i in sn_propose_sorted.keys():
                    if sn_propose_sorted[i]-commit_quorum_time>=g:
                        sn_frontrunning_block_lst[key].append((i,sn_propose_sorted[i]))

        # print(sn_frontrunning_block_lst)
        cnt=[len(sn_frontrunning_block_lst[key]) for key in sn_frontrunning_block_lst]
        print('With g = ' + str(g) + 'ms, the frontrunning block average number is ' + str(np.array(cnt).mean()))

        total_time = max(req_finish.values())-min(req_submit.values())
        print('------------------------------------')
        print('Throughput is '+str(len(req_finish)/(total_time/1000)))
        print('------------------------------------')
