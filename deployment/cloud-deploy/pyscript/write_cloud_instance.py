import sys

print(sys.argv)

server_num=int(sys.argv[1])
client_num=int(sys.argv[2])

num=client_num+server_num

with open('../cloud-instance.info','w') as f:

    public = sys.argv[3:num+3]
    private = sys.argv[num+3:num+num+3]
    
    print(client_num)
    print(server_num)
    print(public)
    print(private)
    
    server_cnt=1
    for i in range(server_num):
        f.write('server-'+str(server_cnt)+' '+public[i]+' '+private[i]+'\n')
        server_cnt=server_cnt+1

    client_cnt=1
    for i in range(server_num,server_num+client_num):
        f.write('client-'+str(client_cnt)+' '+public[i]+' '+private[i]+'\n')
        client_cnt=client_cnt+1
        
    print('Write \'cloud-instance.info\' successfully !')
    
    