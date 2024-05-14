use crate::{DFAGraph, DFAState, DecomposedRegexConfig, RegexAndDFA, SubstrsDefs};
use regex::Regex;
use regex_automata::dfa::{dense::DFA, StartKind};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Debug, Clone)]
struct DFAInfoState {
    typ: String,
    source: usize,
    edges: BTreeMap<String, usize>,
}

#[derive(Debug)]
struct DFAGraphInfo {
    states: Vec<DFAInfoState>,
}

fn parse_dfa_output(output: &str) -> DFAGraphInfo {
    let mut dfa_info = DFAGraphInfo { states: Vec::new() };

    let re = Regex::new(r"\*?(\d+): ((.+?) => (\d+),?)+").unwrap();
    for captures in re.captures_iter(output) {
        let src = captures[1].parse::<usize>().unwrap();
        let mut state = DFAInfoState {
            source: src,
            typ: String::new(),
            edges: BTreeMap::new(),
        };
        if &captures[0][0..1] == "*" {
            state.typ = String::from("accept");
        }
        for transition in Regex::new(r"\s+[^=]+\s*=>\s*(\d+)+\s*|\s+=+\s*=>\s*(\d+)+")
            .unwrap()
            .captures_iter(&captures[0].to_string())
        {
            let trimmed_transition = transition[0].trim();
            let transition_vec = trimmed_transition.split("=>").collect::<Vec<&str>>();
            let mut transition_vec_iter = transition_vec.iter();
            let mut src = transition_vec_iter.next().unwrap().trim().to_string();
            if src.len() > 2
                && src.chars().nth(2).unwrap() == '\\'
                && !(src.chars().nth(3).unwrap() == 'x')
            {
                src = format!("{}{}", &src[0..2], &src[3..]);
            }
            let dst = transition_vec_iter.next().unwrap().trim();
            state.edges.insert(src, dst.parse::<usize>().unwrap());
        }
        dfa_info.states.push(state);
    }

    let mut eoi_pointing_states = BTreeSet::new();

    for state in &mut dfa_info.states {
        if let Some(eoi_target) = state.edges.get("EOI").cloned() {
            eoi_pointing_states.insert(eoi_target);
            state.typ = String::from("accept");
            state.edges.remove("EOI");
        }
    }

    let start_state_re = Regex::new(r"START-GROUP\(anchored\)[\s*\w*\=>]*Text => (\d+)").unwrap();
    let start_state = start_state_re.captures_iter(output).next().unwrap()[1]
        .parse::<usize>()
        .unwrap();

    // Sort states by order of appearance and rename the sources
    let mut sorted_states = DFAGraphInfo { states: Vec::new() };
    let mut sorted_states_set = BTreeSet::new();
    let mut new_states = BTreeSet::new();
    new_states.insert(start_state);
    while !new_states.is_empty() {
        let mut next_states = BTreeSet::new();
        for state in &new_states {
            if let Some(state) = dfa_info.states.iter().find(|s| s.source == *state) {
                sorted_states.states.push((*state).clone());
                sorted_states_set.insert(state.source);
                for (_, dst) in &state.edges {
                    if !sorted_states_set.contains(dst) {
                        next_states.insert(*dst);
                    }
                }
            }
        }
        // Check if the next_states are already in the sorted_states_set
        new_states.clear();
        for state in &next_states {
            if !sorted_states_set.contains(state) {
                new_states.insert(*state);
            }
        }
    }

    // Rename the sources
    let mut switch_states = BTreeMap::new();
    for (i, state) in sorted_states.states.iter_mut().enumerate() {
        let temp = state.source;
        state.source = i as usize;
        switch_states.insert(temp, state.source);
    }

    // Iterate over all edges of all states
    for state in &mut sorted_states.states {
        for (_, dst) in &mut state.edges {
            *dst = switch_states.get(dst).unwrap().clone();
        }
    }

    sorted_states
}

fn dfa_to_graph(dfa_info: &DFAGraphInfo) -> DFAGraph {
    let mut graph = DFAGraph { states: Vec::new() };
    for state in &dfa_info.states {
        let mut edges = BTreeMap::new();
        let key_mappings: BTreeMap<&str, u8> = [
            ("\\n", 10),
            ("\\r", 13),
            ("\\t", 9),
            ("\\v", 11),
            ("\\f", 12),
            ("\\0", 0),
        ]
        .into();
        for (key, value) in &state.edges {
            let mut key: &str = key;
            if key == "' '" {
                key = " ";
            }
            let re = Regex::new(r"(.+)-(.+)").unwrap();
            if re.is_match(key) {
                let capture = re.captures_iter(key).next().unwrap();
                let mut start = &capture[1];
                let start_index;
                if start.starts_with("\\x") {
                    start = &start[2..];
                    start_index = u8::from_str_radix(start, 16).unwrap();
                } else {
                    if key_mappings.contains_key(start) {
                        start_index = *key_mappings.get(start).unwrap();
                    } else {
                        start_index = start.as_bytes()[0];
                    }
                }
                let mut end = &capture[2];
                let end_index;
                if end.starts_with("\\x") {
                    end = &end[2..];
                    end_index = u8::from_str_radix(end, 16).unwrap();
                } else {
                    if key_mappings.contains_key(end) {
                        end_index = *key_mappings.get(end).unwrap();
                    } else {
                        end_index = end.as_bytes()[0];
                    }
                }
                let char_range: Vec<u8> = (start_index..=end_index).collect();
                if edges.contains_key(value) {
                    let edge: &mut BTreeSet<u8> = edges.get_mut(value).unwrap();
                    for c in char_range {
                        edge.insert(c);
                    }
                } else {
                    edges.insert(*value, char_range.into_iter().collect());
                }
            } else {
                let index;
                if key.starts_with("\\x") {
                    key = &key[2..];
                    index = u8::from_str_radix(key, 16).unwrap();
                } else {
                    if key_mappings.contains_key(key) {
                        index = *key_mappings.get(key).unwrap();
                    } else {
                        index = key.as_bytes()[0];
                    }
                }
                if edges.contains_key(value) {
                    let edge: &mut BTreeSet<u8> = edges.get_mut(value).unwrap();
                    edge.insert(index);
                } else {
                    edges.insert(*value, vec![index].into_iter().collect());
                }
            }
        }

        graph.states.push(DFAState {
            r#type: state.typ.clone(),
            edges: edges,
            state: state.source,
        });
    }

    graph
}

fn rename_states(dfa_info: &DFAGraph, base: usize) -> DFAGraph {
    let mut dfa_info = dfa_info.clone();
    // Rename the sources
    let mut switch_states = BTreeMap::new();
    for (i, state) in dfa_info.states.iter_mut().enumerate() {
        let temp = state.state;
        state.state = i + base;
        switch_states.insert(temp, state.state);
    }

    // Iterate over all edges of all states and rename the states
    for state in &mut dfa_info.states {
        let mut new_edges = BTreeMap::new();
        for (key, value) in &state.edges {
            new_edges.insert(*switch_states.get(key).unwrap(), value.clone());
        }
        state.edges = new_edges;
    }

    dfa_info
}

fn add_dfa(net_dfa: &DFAGraph, graph: &DFAGraph) -> DFAGraph {
    if net_dfa.states.is_empty() {
        return graph.clone();
    }
    let mut net_dfa = net_dfa.clone();

    let start_state = graph.states.iter().next().unwrap();

    for state in &mut net_dfa.states {
        if state.r#type == "accept" {
            for (k, v) in &start_state.edges {
                for edge_value in v {
                    for (_, v) in &mut state.edges {
                        if v.contains(edge_value) {
                            v.retain(|val| val != edge_value);
                        }
                    }
                }
                state.edges.insert(*k, v.clone());
            }
            state.r#type = "".to_string();
            if start_state.r#type == "accept" {
                state.r#type = "accept".to_string();
            }
        }
    }

    for state in &graph.states {
        if state.state != start_state.state {
            net_dfa.states.push(state.clone());
        }
    }

    net_dfa
}

pub fn regex_and_dfa(decomposed_regex: &DecomposedRegexConfig) -> RegexAndDFA {
    let mut config = DFA::config().minimize(true);
    config = config.start_kind(StartKind::Anchored);
    config = config.byte_classes(false);
    config = config.accelerate(true);

    let mut net_dfa = DFAGraph { states: Vec::new() };
    let mut substr_defs_array = Vec::new();

    for regex in decomposed_regex.parts.iter() {
        let re = DFA::builder()
            .configure(config.clone())
            .build(&format!(r"^{}$", regex.regex_def))
            .unwrap();
        let re_str = format!("{:?}", re);
        let mut graph = dfa_to_graph(&parse_dfa_output(&re_str));
        // println!("{:?}", graph);
        // Find max state in net_dfa
        let mut max_state_index = 0;
        for state in net_dfa.states.iter() {
            if state.state > max_state_index {
                max_state_index = state.state;
            }
        }

        graph = rename_states(&graph, max_state_index);

        if regex.is_public {
            let mut accepting_states = Vec::new();
            for state in &net_dfa.states {
                if state.r#type == "accept" {
                    accepting_states.push(state);
                }
            }

            let mut public_edges = BTreeSet::new();
            for state in &graph.states {
                for (key, _) in &state.edges {
                    public_edges.insert((state.state, *key));
                }
            }

            if max_state_index != 0 {
                for public_edge in &public_edges.clone() {
                    if public_edge.0 == max_state_index && public_edge.1 == max_state_index {
                        public_edges.remove(&(public_edge.0, public_edge.1));
                        for accept_state in &accepting_states {
                            for accept_state_ in &accepting_states {
                                public_edges.insert((accept_state.state, accept_state_.state));
                            }
                        }
                    } else if public_edge.0 == max_state_index {
                        public_edges.remove(&(public_edge.0, public_edge.1));
                        for accept_state in &accepting_states {
                            public_edges.insert((accept_state.state, public_edge.1));
                        }
                    } else if public_edge.1 == max_state_index {
                        public_edges.remove(&(public_edge.0, public_edge.1));
                        for accept_state in &accepting_states {
                            public_edges.insert((public_edge.0, accept_state.state));
                        }
                    }
                }
            }

            substr_defs_array.push(public_edges);
        }

        net_dfa = add_dfa(&net_dfa, &graph);
    }
    // println!("{:?}", net_dfa);

    let mut regex_str = String::new();
    for regex in decomposed_regex.parts.iter() {
        regex_str += &regex.regex_def;
    }

    RegexAndDFA {
        regex_str: regex_str,
        dfa_val: net_dfa,
        substrs_defs: SubstrsDefs {
            substr_defs_array: substr_defs_array,
            substr_endpoints_array: None,
        },
    }
}

pub fn dfa_from_regex_str(regex: &str) -> DFAGraph {
    let mut config = DFA::config().minimize(true);
    config = config.start_kind(StartKind::Anchored);
    config = config.byte_classes(false);
    config = config.accelerate(true);
    let re = DFA::builder()
        .configure(config)
        .build(&format!(r"^{}$", regex))
        .unwrap();
    let re_str = format!("{:?}", re);
    let graph = dfa_to_graph(&parse_dfa_output(&re_str));
    graph
}
