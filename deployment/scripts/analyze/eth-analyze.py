import pandas as pd

# 读取CSV文件
df = pd.read_csv('ethtx.csv')

df

# 检查'type'列中是否包含值'Transfer'
transfer_count = df[df['Method'] == 'Transfer'].shape[0]

# 输出结果
print(f"有 {transfer_count} 条记录的类型为 'Transfer'")

# 523/968 = 54.0%