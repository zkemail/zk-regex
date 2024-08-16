use crate::{
    errors::CompilerError,
    structs::{
        DFAGraph, DFAGraphInfo, DFAStateInfo, DFAStateNode, RegexAndDFA, RegexPartConfig,
        SubstringDefinitions, SubstringDefinitionsJson,
    },
    DecomposedRegexConfig,
};
use regex::Regex;
use regex_automata::dfa::{
    dense::{Config, DFA},
    StartKind,
};
use std::{
    collections::{BTreeMap, BTreeSet, VecDeque},
    num::ParseIntError,
};

fn create_dfa_config() -> Config {
    let mut config = DFA::config().minimize(true);
    config = config.start_kind(StartKind::Anchored);
    config = config.byte_classes(false);
    config = config.accelerate(true);
    config
}

fn find_caret_index(regex: &str) -> Option<usize> {
    let regex_bytes = regex.as_bytes();
    let mut is_in_parenthesis = false;
    let mut caret_found = false;
    let mut idx = 0;

    while idx < regex_bytes.len() {
        match regex_bytes[idx] {
            b'\\' => {
                idx += 2;
            }
            b'(' => {
                is_in_parenthesis = true;
                idx += 1;
            }
            b'[' => {
                idx += 2;
            }
            b')' => {
                debug_assert!(is_in_parenthesis, "Unmatched parenthesis");
                is_in_parenthesis = false;
                idx += 1;
                if caret_found {
                    break;
                }
            }
            b'^' => {
                caret_found = true;
                idx += 1;
                if !is_in_parenthesis {
                    break;
                }
            }
            _ => {
                idx += 1;
            }
        }
    }

    if caret_found {
        Some(idx)
    } else {
        None
    }
}

fn process_caret_in_regex(
    decomposed_regex: &mut DecomposedRegexConfig,
) -> Result<Option<usize>, CompilerError> {
    let caret_position = find_caret_index(&decomposed_regex.parts[0].regex_def);

    if let Some(index) = caret_position {
        let caret_regex = decomposed_regex.parts[0].regex_def[0..index].to_string();
        decomposed_regex.parts.push_front(RegexPartConfig {
            is_public: false,
            regex_def: caret_regex,
        });
        decomposed_regex.parts[1].regex_def =
            decomposed_regex.parts[1].regex_def[index..].to_string();
    }

    Ok(caret_position)
}

fn validate_end_anchor(
    decomposed_regex: &DecomposedRegexConfig,
    idx: usize,
    regex: &RegexPartConfig,
) -> Result<bool, CompilerError> {
    let is_last_part = idx == decomposed_regex.parts.len() - 1;
    let ends_with_dollar = regex.regex_def.ends_with('$');

    if ends_with_dollar && !is_last_part {
        return Err(CompilerError::GenericError(
            "Invalid regex, $ can only be at the end of the regex".to_string(),
        ));
    }

    Ok(is_last_part && ends_with_dollar)
}

fn parse_states(output: &str, dfa_info: &mut DFAGraphInfo) -> Result<(), CompilerError> {
    let state_re = Regex::new(r"\*?(\d+): ((.+?) => (\d+),?)+")?;
    let transition_re = Regex::new(
        r"\s+[^=]+\s*=>\s*(\d+)+\s*|\s+=+\s*=>\s*(\d+)+|\s+=-[^=]+=>\s*\s*(\d+)+\s*|\s+[^=]+-=\s*=>\s*(\d+)+\s*",
    )?;

    for captures in state_re.captures_iter(output) {
        let src = captures[1]
            .parse::<usize>()
            .map_err(|_| CompilerError::ParseError("Failed to parse state ID".to_string()))?;

        let mut state = DFAStateInfo {
            source: src,
            typ: if captures[0].starts_with('*') {
                "accept".to_string()
            } else {
                String::new()
            },
            edges: BTreeMap::new(),
        };

        for transition in transition_re.captures_iter(&captures[0]) {
            parse_transition(&mut state, &transition[0])?;
        }

        dfa_info.states.push(state);
    }

    Ok(())
}

fn parse_transition(state: &mut DFAStateInfo, transition: &str) -> Result<(), CompilerError> {
    let parts: Vec<&str> = transition.split("=>").collect();
    if parts.len() != 2 {
        return Err(CompilerError::ParseError(
            "Invalid transition format".to_string(),
        ));
    }

    let mut src = parts[0].trim().to_string();
    if src.len() > 2 && src.chars().nth(2) == Some('\\') && src.chars().nth(3) != Some('x') {
        src = format!("{}{}", &src[0..2], &src[3..]);
    }

    let dst = parts[1]
        .trim()
        .parse::<usize>()
        .map_err(|_| CompilerError::ParseError("Failed to parse destination state".to_string()))?;

    state.edges.insert(src, dst);
    Ok(())
}

fn handle_eoi_transitions(dfa_info: &mut DFAGraphInfo) {
    for state in &mut dfa_info.states {
        if let Some(_) = state.edges.get("EOI") {
            state.typ = String::from("accept");
            state.edges.remove("EOI");
        }
    }
}

fn find_start_state(output: &str) -> Result<usize, CompilerError> {
    let start_state_re = Regex::new(r"START-GROUP\(anchored\)[\s*\w*\=>]*Text => (\d+)")?;
    start_state_re
        .captures(output)
        .and_then(|cap| cap[1].parse::<usize>().ok())
        .ok_or_else(|| CompilerError::ParseError("Failed to find start state".to_string()))
}

fn sort_and_rename_states(dfa_info: &DFAGraphInfo, start_state: usize) -> DFAGraphInfo {
    let mut sorted_states = Vec::new();
    let mut visited = BTreeSet::new();
    let mut queue = VecDeque::new();
    queue.push_back(start_state);

    // BFS to sort states
    while let Some(state_id) = queue.pop_front() {
        if visited.insert(state_id) {
            if let Some(state) = dfa_info.states.iter().find(|s| s.source == state_id) {
                sorted_states.push(state.clone());
                queue.extend(state.edges.values().filter(|&dst| !visited.contains(dst)));
            }
        }
    }

    // Create mapping of old state IDs to new state IDs
    let state_map: BTreeMap<_, _> = sorted_states
        .iter()
        .enumerate()
        .map(|(new_id, state)| (state.source, new_id))
        .collect();

    // Rename states and update edges
    let renamed_states = sorted_states
        .into_iter()
        .enumerate()
        .map(|(new_id, mut state)| {
            state.source = new_id;
            for dst in state.edges.values_mut() {
                *dst = *state_map.get(dst).unwrap_or(dst);
            }
            state
        })
        .collect();

    DFAGraphInfo {
        states: renamed_states,
    }
}

fn create_special_char_mappings() -> BTreeMap<&'static str, u8> {
    [
        ("\\n", 10),
        ("\\r", 13),
        ("\\t", 9),
        ("\\v", 11),
        ("\\f", 12),
        ("\\0", 0),
        ("\\\"", 34),
        ("\\'", 39),
        ("\\", 92),
        ("' '", 32),
    ]
    .iter()
    .cloned()
    .collect()
}

fn process_edge(
    key: &str,
    value: usize,
    edges: &mut BTreeMap<usize, BTreeSet<u8>>,
    special_char_mappings: &BTreeMap<&str, u8>,
) -> Result<(), CompilerError> {
    let re = Regex::new(r"(.+)-(.+)")?;
    if re.is_match(key) {
        process_range_edge(key, value, edges, special_char_mappings, &re)?;
    } else {
        process_single_edge(key, value, edges, special_char_mappings)?;
    }
    Ok(())
}

fn process_range_edge(
    key: &str,
    value: usize,
    edges: &mut BTreeMap<usize, BTreeSet<u8>>,
    special_char_mappings: &BTreeMap<&str, u8>,
    re: &Regex,
) -> Result<(), CompilerError> {
    let capture = re
        .captures(key)
        .ok_or_else(|| CompilerError::ParseError("Failed to capture range".to_string()))?;
    let start_index = parse_char(&capture[1], special_char_mappings)?;
    let end_index = parse_char(&capture[2], special_char_mappings)?;
    let char_range: Vec<u8> = (start_index..=end_index).collect();

    edges
        .entry(value)
        .or_insert_with(BTreeSet::new)
        .extend(char_range);
    Ok(())
}

fn process_single_edge(
    key: &str,
    value: usize,
    edges: &mut BTreeMap<usize, BTreeSet<u8>>,
    special_char_mappings: &BTreeMap<&str, u8>,
) -> Result<(), CompilerError> {
    let index = parse_char(key, special_char_mappings)?;
    edges
        .entry(value)
        .or_insert_with(BTreeSet::new)
        .insert(index);
    Ok(())
}

fn parse_char(s: &str, special_char_mappings: &BTreeMap<&str, u8>) -> Result<u8, CompilerError> {
    if s.starts_with("\\x") {
        u8::from_str_radix(&s[2..], 16)
            .map_err(|e: ParseIntError| CompilerError::ParseError(e.to_string()))
    } else if let Some(&value) = special_char_mappings.get(s) {
        Ok(value)
    } else if s.len() == 1 {
        Ok(s.as_bytes()[0])
    } else {
        Err(CompilerError::ParseError(format!(
            "Invalid character: {}",
            s
        )))
    }
}

fn process_state_edges(
    state_edges: &BTreeMap<String, usize>,
) -> Result<BTreeMap<usize, BTreeSet<u8>>, CompilerError> {
    let mut edges = BTreeMap::new();
    let special_char_mappings = create_special_char_mappings();

    for (key, value) in state_edges {
        let key = if key == "' '" { " " } else { key };
        process_edge(key, *value, &mut edges, &special_char_mappings)?;
    }

    Ok(edges)
}

fn convert_dfa_to_graph(dfa: DFA<Vec<u32>>) -> Result<DFAGraph, CompilerError> {
    let dfa_str = format!("{:?}", dfa);

    let mut dfa_info = DFAGraphInfo { states: Vec::new() };

    parse_states(&dfa_str, &mut dfa_info)?;

    handle_eoi_transitions(&mut dfa_info);

    let start_state = find_start_state(&dfa_str)?;
    dfa_info = sort_and_rename_states(&mut dfa_info, start_state);

    let mut graph = DFAGraph { states: Vec::new() };
    for state in &dfa_info.states {
        let edges = process_state_edges(&state.edges)?;
        graph.states.push(DFAStateNode {
            state_type: state.typ.clone(),
            state_id: state.source,
            transitions: edges,
        });
    }

    Ok(graph)
}

fn modify_graph_for_caret(graph: &mut DFAGraph) -> Result<(), CompilerError> {
    if let Some(start_state) = graph.states.get_mut(0) {
        start_state.state_type.clear();
    } else {
        return Err(CompilerError::GraphError(
            "Start state not found".to_string(),
        ));
    }

    let accepted_state = graph
        .states
        .iter()
        .find(|state| state.state_type == "accept")
        .ok_or_else(|| CompilerError::GraphError("Accept state not found".to_string()))?
        .clone();

    if let Some(start_state) = graph.states.get_mut(0) {
        start_state
            .transitions
            .entry(accepted_state.state_id)
            .or_insert_with(BTreeSet::new)
            .insert(255u8);
    }

    Ok(())
}

fn create_simple_caret_graph() -> DFAGraph {
    DFAGraph {
        states: vec![
            DFAStateNode {
                state_type: String::new(),
                state_id: 0,
                transitions: BTreeMap::from([(1, BTreeSet::from([255u8]))]),
            },
            DFAStateNode {
                state_type: "accept".to_string(),
                state_id: 1,
                transitions: BTreeMap::new(),
            },
        ],
    }
}

fn handle_caret_regex(
    idx: usize,
    caret_position: Option<usize>,
    regex: &RegexPartConfig,
    graph: &mut DFAGraph,
) -> Result<(), CompilerError> {
    if idx == 0 && caret_position.is_some() {
        if regex.regex_def == "^" {
            *graph = create_simple_caret_graph();
        } else {
            modify_graph_for_caret(graph)?;
        }
    }
    Ok(())
}

fn rename_states(dfa_graph: &DFAGraph, base: usize) -> DFAGraph {
    let state_id_mapping: BTreeMap<_, _> = dfa_graph
        .states
        .iter()
        .enumerate()
        .map(|(i, state)| (state.state_id, i + base))
        .collect();

    DFAGraph {
        states: dfa_graph
            .states
            .iter()
            .enumerate()
            .map(|(i, state)| DFAStateNode {
                state_id: i + base,
                transitions: state
                    .transitions
                    .iter()
                    .map(|(key, value)| {
                        (
                            *state_id_mapping.get(key).expect("State not found"),
                            value.clone(),
                        )
                    })
                    .collect(),
                ..state.clone()
            })
            .collect(),
    }
}

fn collect_accepting_states(net_dfa: &DFAGraph) -> (Vec<&DFAStateNode>, BTreeSet<usize>) {
    let mut accepting_states = Vec::new();
    let mut substring_starts = BTreeSet::new();

    for state in &net_dfa.states {
        if state.state_type == "accept" {
            accepting_states.push(state);
            substring_starts.insert(state.state_id);
        }
    }

    (accepting_states, substring_starts)
}

fn collect_public_edges(graph: &DFAGraph) -> BTreeSet<(usize, usize)> {
    graph
        .states
        .iter()
        .flat_map(|state| {
            state
                .transitions
                .keys()
                .map(move |&key| (state.state_id, key))
        })
        .collect()
}

fn collect_substr_ends(graph: &DFAGraph) -> BTreeSet<usize> {
    graph
        .states
        .iter()
        .filter(|state| state.state_type == "accept")
        .map(|state| state.state_id)
        .collect()
}

fn update_public_edges(
    public_edges: &mut BTreeSet<(usize, usize)>,
    max_state_index: usize,
    accepting_states: &[&DFAStateNode],
) {
    if max_state_index == 0 {
        return;
    }

    let edges_to_update: Vec<_> = public_edges
        .iter()
        .filter(|&&(from, to)| (from == max_state_index || to == max_state_index))
        .cloned()
        .collect();

    for (from, to) in edges_to_update {
        public_edges.remove(&(from, to));

        if from == max_state_index && to == max_state_index {
            for &accept_from in accepting_states {
                for &accept_to in accepting_states {
                    public_edges.insert((accept_from.state_id, accept_to.state_id));
                }
            }
        } else if from == max_state_index {
            for &accept_state in accepting_states {
                public_edges.insert((accept_state.state_id, to));
            }
        } else if to == max_state_index {
            for &accept_state in accepting_states {
                public_edges.insert((from, accept_state.state_id));
            }
        }
    }
}

fn process_public_regex(
    regex: &RegexPartConfig,
    net_dfa: &DFAGraph,
    graph: &DFAGraph,
    previous_max_state_id: usize,
) -> (BTreeSet<(usize, usize)>, (BTreeSet<usize>, BTreeSet<usize>)) {
    if !regex.is_public {
        return (BTreeSet::new(), (BTreeSet::new(), BTreeSet::new()));
    }

    let (accepting_states, substring_starts) = collect_accepting_states(net_dfa);
    let mut public_edges = collect_public_edges(graph);
    let substring_ends = collect_substr_ends(graph);

    update_public_edges(&mut public_edges, previous_max_state_id, &accepting_states);

    (public_edges, (substring_starts, substring_ends))
}

fn merge_edges(target_state: &mut DFAStateNode, source_state: &DFAStateNode) {
    for (k, v) in &source_state.transitions {
        for edge_value in v {
            target_state.transitions.values_mut().for_each(|values| {
                values.retain(|val| val != edge_value);
            });
        }
        target_state.transitions.insert(*k, v.clone());
    }
}

fn update_state_type(target_state: &mut DFAStateNode, source_state: &DFAStateNode) {
    target_state.state_type.clear();
    if source_state.state_type == "accept" {
        target_state.state_type = "accept".to_string();
    }
}

fn process_accept_state(accept_state: &mut DFAStateNode, start_state: &DFAStateNode) {
    merge_edges(accept_state, start_state);
    update_state_type(accept_state, start_state);
}

fn add_dfa(net_dfa: &DFAGraph, graph: &DFAGraph) -> DFAGraph {
    if net_dfa.states.is_empty() {
        return graph.clone();
    }

    let mut new_dfa = net_dfa.clone();
    let start_state = graph.states.first().expect("Graph has no states");

    new_dfa
        .states
        .iter_mut()
        .filter(|state| state.state_type == "accept")
        .for_each(|state| process_accept_state(state, start_state));

    new_dfa.states.extend(
        graph
            .states
            .iter()
            .filter(|state| state.state_id != start_state.state_id)
            .cloned(),
    );

    new_dfa
}

pub(crate) fn get_regex_and_dfa(
    decomposed_regex: &mut DecomposedRegexConfig,
) -> Result<RegexAndDFA, CompilerError> {
    let mut net_dfa_graph = DFAGraph { states: Vec::new() };
    let mut substring_ranges_array = Vec::new();
    let mut ubstring_boundaries_array = Vec::new();

    let config = create_dfa_config();

    let caret_position = process_caret_in_regex(decomposed_regex)?;

    let mut end_anchor = false;

    for (i, regex) in decomposed_regex.parts.iter().enumerate() {
        end_anchor = validate_end_anchor(decomposed_regex, i, regex)?;

        let dfa = DFA::builder()
            .configure(config.clone())
            .build(&format!(r"^({})$", regex.regex_def.as_str()))
            .map_err(|err| CompilerError::BuildError {
                regex: regex.regex_def.clone(),
                source: err,
            })?;

        let mut dfa_graph = convert_dfa_to_graph(dfa)?;

        handle_caret_regex(i, caret_position, regex, &mut dfa_graph)?;

        let max_state_index = net_dfa_graph
            .states
            .iter()
            .map(|state| state.state_id)
            .max()
            .unwrap_or(0);

        dfa_graph = rename_states(&dfa_graph, max_state_index);

        if regex.is_public {
            let (public_edges, (substr_starts, substr_ends)) =
                process_public_regex(regex, &net_dfa_graph, &dfa_graph, max_state_index);
            substring_ranges_array.push(public_edges);
            ubstring_boundaries_array.push((substr_starts, substr_ends));
        }

        net_dfa_graph = add_dfa(&net_dfa_graph, &dfa_graph);
    }

    let regex_str = decomposed_regex
        .parts
        .iter()
        .map(|regex| regex.regex_def.as_str())
        .collect::<String>();

    Ok(RegexAndDFA {
        regex_pattern: regex_str,
        dfa: net_dfa_graph,
        has_end_anchor: end_anchor,
        substrings: SubstringDefinitions {
            substring_ranges: substring_ranges_array,
            substring_boundaries: Some(ubstring_boundaries_array),
        },
    })
}

fn create_dfa_graph_from_regex(regex: &str) -> Result<DFAGraph, CompilerError> {
    let config = DFA::config()
        .minimize(true)
        .start_kind(StartKind::Anchored)
        .byte_classes(false)
        .accelerate(true);

    let dfa = DFA::builder()
        .configure(config)
        .build(&format!(r"^{}$", regex))
        .map_err(|e| CompilerError::BuildError {
            regex: regex.to_string(),
            source: e,
        })?;

    convert_dfa_to_graph(dfa)
}

pub(crate) fn create_regex_and_dfa_from_str_and_defs(
    regex_str: &str,
    substrs_defs_json: SubstringDefinitionsJson,
) -> Result<RegexAndDFA, CompilerError> {
    let dfa = create_dfa_graph_from_regex(regex_str)?;

    let substring_ranges = substrs_defs_json
        .transitions
        .into_iter()
        .map(|transitions| {
            transitions
                .into_iter()
                .collect::<BTreeSet<(usize, usize)>>()
        })
        .collect();

    let substrings = SubstringDefinitions {
        substring_ranges,
        substring_boundaries: None,
    };

    Ok(RegexAndDFA {
        regex_pattern: regex_str.to_string(),
        dfa,
        has_end_anchor: regex_str.ends_with('$'),
        substrings,
    })
}

pub(crate) fn get_accepted_state(dfa: &DFAGraph) -> Option<usize> {
    dfa.states
        .iter()
        .position(|state| state.state_type == "accept")
}

pub(crate) fn get_max_state(dfa: &DFAGraph) -> usize {
    dfa.states
        .iter()
        .map(|state| state.state_id)
        .max()
        .unwrap_or_default()
}
