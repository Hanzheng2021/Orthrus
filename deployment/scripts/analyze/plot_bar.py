import matplotlib.pyplot as plt
import numpy as np

fig, ax = plt.subplots(figsize=(8,6), dpi=600)

name = np.array(["Target throughput: 8192", "Target throughput: 16384"])
y = np.array([2982.6863120897547,8547.215252923279,805.3771813441851,14119.625485135135])

a = np.array([8547.215252923279,8874.723696576542])
b = np.array([2982.6863120897547,3282.6863120897547])

c = np.array([805.3771813441851,726.1886437836515])
d = np.array([14119.625485135135,15215.262512523642])


x = np.arange(2)
total_width, n = 5, 25
width = total_width / n
x = x - (total_width - width) / 2

plt.ylim((0,11000))
plt.bar(x, a,  width=width, label='Normal')
plt.bar(x + width, b, width=width, label='Straggler')
# plt.bar(x + 2 * width, c, width=width, label='c')
plt.legend()
plt.xticks(x+width/2,name,fontsize = 12)

ax.set_title('Throughput of cloud deployment',fontsize=14,y=1.05)
ax.set_ylabel('throughput / req/s',fontsize = 14,color = 'black',rotation=90)

plt.text(x[0],a[0],int(a[0]),ha='center',va='bottom',fontsize=12)
plt.text(x[1],a[1],int(a[1]),ha='center',va='bottom',fontsize=12)
plt.text(x[0]+width,b[0],int(b[0]),ha='center',va='bottom',fontsize=12)
plt.text(x[1]+width,b[1],int(b[1]),ha='center',va='bottom',fontsize=12)

plt.savefig('scripts/analyze/throughput.png', dpi=600)
