import re

if __name__=='__main__':
    with open('scripts/cloud-deploy/cloud-instance-info') as f:
        lines=f.readlines()
        for line in lines:
            find_peer=re.search(r'p\d+\s',line)
            # print(find_peer)
            if find_peer is not None:
                # print(line)
                print(line.split(" ")[1],end=' ')
            
                
                