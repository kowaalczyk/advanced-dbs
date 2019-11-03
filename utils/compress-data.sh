#tar cf - data -P | pv -s $(du -sb data | awk '{print $1}') | gzip > data.tar.gz
tar cf - out -P | pv -s $(du -sb out | awk '{print $1}') | gzip > out.tar.gz
# https://superuser.com/questions/168749/is-there-a-way-to-see-any-tar-progress-per-file
# decompress using:
# tar xvzf data.tar.gz
