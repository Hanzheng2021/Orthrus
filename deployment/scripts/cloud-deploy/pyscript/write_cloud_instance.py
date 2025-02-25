import sys

regionCnt = 4    
client_num=int(sys.argv[1])
eachRegionClient=client_num//regionCnt
peer_num=int(sys.argv[2])
eachRegionPeer=peer_num//regionCnt
eachRegionCnt = (client_num+peer_num)//regionCnt

num=int((len(sys.argv)-3)/2)

with open('scripts/cloud-deploy/cloud-instance-info','w') as f:
    f.write('master '+sys.argv[3]+' '+sys.argv[num+3]+' master us-west-2a\n')

    client_str='1client'
    extra_client_str=''
    if client_num==16:
        client_str='16clients'
    if client_num==32:
        client_str='16clients'
        extra_client_str='16extraclients'

    public = sys.argv[4:num+3]
    private = sys.argv[num+4:num+num+3]
    
    # print(client_num)
    # print(peer_num)
    # print(public)
    # print(private)
    
    clicnt=1
    for i in range(regionCnt):
        if client_num==1:
            f.write('client '+public[0]+' '+private[0]+' '+client_str+' us-west-2a\n')
            public.pop(0)
            private.pop(0)
            
            # print(public)
            # print(private)

            break
        else:
            for j in range(eachRegionClient):
                if clicnt <= 16:
                    # print('client '+public[j+i*eachRegionCnt]+' '+private[j+i*eachRegionCnt]+' '+client_str+' us-west-2a\n')
                    f.write('client '+public[j+i*eachRegionCnt]+' '+private[j+i*eachRegionCnt]+' '+client_str+' us-west-2a\n')
                else:
                    f.write('client '+public[j+i*eachRegionCnt]+' '+private[j+i*eachRegionCnt]+' '+extra_client_str+' us-west-2a\n')
                clicnt+=1
                    
        
    peercnt=1
    for i in range(regionCnt):
        for j in range(eachRegionPeer):
            # print('p'+str(peercnt)+' '+public[j+eachRegionClient+i*eachRegionCnt]+' '+private[j+eachRegionClient+i*eachRegionCnt]+' peers us-west-2a\n')
            f.write('p'+str(peercnt)+' '+public[j+eachRegionClient+i*eachRegionCnt]+' '+private[j+eachRegionClient+i*eachRegionCnt]+' peers us-west-2a\n')
            peercnt+=1
        
    print('Write \'cloud-instance-info\' successfully !')
    
    