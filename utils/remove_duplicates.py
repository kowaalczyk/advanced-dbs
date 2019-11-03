import gc
import os
import csv

import pandas as pd
from tqdm import tqdm


if __name__ == '__main__':
    if not gc.isenabled():
        gc.enable()
    t = tqdm(os.listdir('data'))
    for f in t:
        if str(f).endswith('csv'):
            t.set_postfix_str(f)
            df = pd.read_csv(os.path.join('data', f))
            df.drop_duplicates(inplace=True)
            df.to_csv(os.path.join('data', f), quoting=csv.QUOTE_NONNUMERIC, index=False)
            del df
            gc.collect()
    t.close()
