import argparse
import patsy
import pandas as pd

parser = argparse.ArgumentParser()
parser.add_argument('--columns')
parser.add_argument('--data')
parser.add_argument('--min_rows', default=5)  # patsy default

args = parser.parse_args()

with open(args.columns, 'r') as file:
    columns = file.read().split()

data = patsy.demo_data(*columns, min_rows=int(args.min_rows))

pd.DataFrame(data).to_feather(args.data)
