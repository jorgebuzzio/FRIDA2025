/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

// ---------------------------------------------------------------------------
// CONSTANTES
// ---------------------------------------------------------------------------
const bit<16> ETHERTYPE_IPV4 = 0x0800;
const bit<8>  IPV4_TCP = 6;
const bit<8>  IPV4_UDP = 17;

// Constantes de normalización (divisores)
const bit<32> TOT_FWD_PKTS = 8;
const bit<32> PKT_LEN_MIN = 6;
const bit<32> FWD_PKT_LEN_MAX = 46;
const bit<32> FWD_IAT_MAX = 910128;
const bit<32> FWD_IAT_MIN = 258815;

// ---------------------------------------------------------------------------
// HEADERS & METADATA (Sin cambios)
// ---------------------------------------------------------------------------
typedef bit<16>  port_num_t;
typedef bit<48> mac_addr_t;

header ingress_intrinsic_metadata_t {
    bit<64> ingress_global_timestamp;
}

header ethernet_t {
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    bit<16>    ether_type;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  tos;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> src_addr;
    bit<32> dst_addr;
}

header tcp_t {
    bit<16> src_port;
    bit<16> dst_port;
    bit<32> seq_no;
    bit<32> ack_no;
    bit<4>  data_offset;
    bit<3>  res;
    bit<3>  ecn;
    bit<1>  urg;
    bit<1>  ack;
    bit<1>  psh;
    bit<1>  rst;
    bit<1>  syn;
    bit<1>  fin;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgent_ptr;
}

header udp_t {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> length_;
    bit<16> checksum;
}

struct parsed_headers_t {
    ingress_intrinsic_metadata_t intrinsic_metadata;
    ethernet_t  ethernet;
    ipv4_t      ipv4;
    tcp_t       tcp;
    udp_t       udp;
}

struct local_metadata_t {
    bit<32> flow_id;
    bit<32> timediff;
    bit<32> pkts;
    bit<32> max_iat;
    bit<32> min_iat;
    bit<32> pkt_min;
    bit<32> fwd_pkt_max;
}

// ---------------------------------------------------------------------------
// PARSER (Sin cambios)
// ---------------------------------------------------------------------------
parser ParserImpl (packet_in packet,
                   out parsed_headers_t hdr,
                   inout local_metadata_t local_metadata,
                   inout standard_metadata_t standard_metadata) {

    state start {
        //packet.extract(hdr.intrinsic_metadata);
        transition parseEthernet;
    }

    state parseEthernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type){
            ETHERTYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IPV4_TCP: parse_tcp;
            IPV4_UDP: parse_udp;
            default: accept;
        }
    }

    state parse_tcp {
        packet.extract(hdr.tcp);
        transition accept;
    }

    state parse_udp {
        packet.extract(hdr.udp);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// INGRESS
// ---------------------------------------------------------------------------
control IngressPipeImpl (inout parsed_headers_t    hdr,
                         inout local_metadata_t    local_metadata,
                         inout standard_metadata_t standard_metadata) {
    
    register<bit<32>>(128) diferencia;
    register<bit<32>>(128) last_timestamp;
    register<bit<32>>(128) fwd_pkt_len_max;
    register<bit<32>>(128) pkt_len_min;
    register<bit<32>>(128) fwd_iat_max;
    register<bit<32>>(128) fwd_iat_min;
    register<bit<32>>(128) tot_fwd_pkts;
    register<bit<8>>(4)    conf_matrix;
    register<bit<16>>(1)   dbg_port;

    action drop() {
        mark_to_drop(); 
    }

    action set_egress_port(port_num_t port_num) {
        standard_metadata.egress_spec = port_num;
        dbg_port.write(0, port_num);
    }

    action update_confusion_matrix(bit<32> idx) {
        bit<8> val;
        conf_matrix.read(val, idx);
        conf_matrix.write(idx, val + 1);
    }

    table ipv4_forward {
        key = {
            standard_metadata.ingress_port: exact;
            //hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            set_egress_port;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    apply {
        if (hdr.ipv4.isValid()) {

            //hash(local_metadata.flow_id, HashAlgorithm.crc32, (bit<32>)0, 
            //        {hdr.ipv4.src_addr, hdr.ipv4.dst_addr, hdr.ipv4.protocol, hdr.tcp.src_port, hdr.tcp.dst_port}, 
            //        (bit<32>)128); 

            //bit<32> curr_time = (bit<32>)hdr.intrinsic_metadata.ingress_global_timestamp;
            //hdr.intrinsic_metadata.setInvalid();

            //bit<32> prev_time;
            //last_timestamp.read(prev_time, local_metadata.flow_id);
            //local_metadata.timediff = curr_time - prev_time;
            //last_timestamp.write(local_metadata.flow_id, curr_time);


            //diferencia.write(local_metadata.flow_id, local_metadata.timediff);


            ipv4_forward.apply();
        }
    }
}

// ---------------------------------------------------------------------------
// EGRESS & DEPARSER (Sin cambios)
// ---------------------------------------------------------------------------
control VerifyChecksumImpl(inout parsed_headers_t hdr, inout local_metadata_t meta){
    apply { }
}

control ComputeChecksumImpl(inout parsed_headers_t hdr, inout local_metadata_t local_metadata) {
    apply { }
}

control EgressPipeImpl (inout parsed_headers_t hdr,
                        inout local_metadata_t local_metadata,
                        inout standard_metadata_t standard_metadata) {
    apply { }
}

control DeparserImpl(packet_out packet, in parsed_headers_t hdr) {
    apply {
        packet.emit(hdr.intrinsic_metadata);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
        packet.emit(hdr.udp);
    }
}

V1Switch(
    ParserImpl(),
    VerifyChecksumImpl(),
    IngressPipeImpl(),
    EgressPipeImpl(),
    ComputeChecksumImpl(),
    DeparserImpl()
) main;

