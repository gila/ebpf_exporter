#include <vmlinux.h>
#include <bpf/bpf_helpers.h>
#include "maps.bpf.h"

enum NFS_OPS {
    READ,
    READ_BYTES,
    WRITE,
    WRITE_BYTES,
};

struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 4);
    __type(key, u32);
    __type(value, u64);
} nfs_client_ops SEC(".maps");

struct nfs_args_common {
    unsigned long __pad;
    u32 dev;
    u32 fhandle;
    u64 fileid;
    u64 offset;
    u32 arg_count;
    u32 arg_res;
    u64 error;
    s32 statid_seq;
    u32 staid_hash;
    u32 layoutstateid_seq;
    u32 layoutstateid_hash;
};

SEC("tracepoint/nfs4/nfs4_read")
int nfs4_read(struct nfs_args_common *args)
{
    u32 r_key = READ;
    u32 b_key = READ_BYTES;

    increment_map(&nfs_client_ops, &r_key, 1);
    increment_map(&nfs_client_ops, &b_key, args->arg_count);
    return 0;
}

SEC("tracepoint/nfs4/nfs4_write")
int nfs4_write(struct nfs_args_common *args)
{
    u32 w_key = WRITE;
    u32 b_key = WRITE_BYTES;

    increment_map(&nfs_client_ops, &w_key, 1);
    increment_map(&nfs_client_ops, &b_key, args->arg_count);
    return 0;
}

char LICENSE[] SEC("license") = "GPL";
