

export
  setMsgUpThis!,
  getDwnMsgsThis


## =============================================================================


lockUpStatus!(cdat::BayesTreeNodeData, idx::Int=1) = put!(cdat.lockUpStatus, idx)
lockUpStatus!(cliq::TreeClique, idx::Int=1) = lockUpStatus!(getCliqueData(cliq), idx)
unlockUpStatus!(cdat::BayesTreeNodeData) = take!(cdat.lockUpStatus)
unlockUpStatus!(cliq::TreeClique) = unlockUpStatus!(getCliqueData(cliq))

function lockDwnStatus!(cdat::BayesTreeNodeData, idx::Int=1; logger=ConsoleLogger())
  with_logger(logger) do
    @info "lockDwnStatus! isready=$(isready(cdat.lockDwnStatus)) with data $(cdat.lockDwnStatus.data)"
  end
  flush(logger.stream)
  stf =  put!(cdat.lockDwnStatus, idx)
  with_logger(logger) do
    @info "lockDwnStatus! DONE: isready=$(isready(cdat.lockDwnStatus)) with data $(cdat.lockDwnStatus.data)"
  end
  flush(logger.stream)
  stf
end
unlockDwnStatus!(cdat::BayesTreeNodeData) = take!(cdat.lockDwnStatus)


"""
    $SIGNATURES

Remove and return a belief message from the down tree message channel edge. Blocks until data is available.
"""
function takeBeliefMessageDown!(tree::BayesTree, edge)
  # Blocks until data is available.
  beliefMsg = take!(tree.messages[edge.index].downMsg)
  return beliefMsg
end

function takeBeliefMessageDown!(tree::MetaBayesTree, edge)
  # Blocks until data is available.
  beliefMsg = take!(MetaGraphs.get_prop(tree.bt, edge, :downMsg))
  return beliefMsg
end


"""
    $SIGNATURES

Remove and return belief message from the up tree message channel edge. Blocks until data is available.
"""
function takeBeliefMessageUp!(tree::BayesTree, edge)
  # Blocks until data is available.
  beliefMsg = take!(tree.messages[edge.index].upMsg)
  return beliefMsg
end

# TODO consolidate
function takeBeliefMessageUp!(tree::MetaBayesTree, edge)
  # Blocks until data is available.
  beliefMsg = take!(MetaGraphs.get_prop(tree.bt, edge, :upMsg))
  return beliefMsg
end


"""
    $SIGNATURES

Put a belief message on the down tree message channel edge. Blocks until a take! is performed by a different task.
"""
function putBeliefMessageDown!(tree::BayesTree, edge, beliefMsg::LikelihoodMessage)
  # Blocks until data is available.
  put!(tree.messages[edge.index].downMsg, beliefMsg)
  return beliefMsg
end

function putBeliefMessageDown!(tree::MetaBayesTree, edge, beliefMsg::LikelihoodMessage)
  # Blocks until data is available.
  put!(MetaGraphs.get_prop(tree.bt, edge, :downMsg), beliefMsg)
  return beliefMsg
end


"""
    $SIGNATURES

Put a belief message on the up tree message channel `edge`. Blocks until a take! is performed by a different task.
"""
function putBeliefMessageUp!(tree::BayesTree, edge, beliefMsg::LikelihoodMessage)
  # Blocks until data is available.
  put!(tree.messages[edge.index].upMsg, beliefMsg)
  return beliefMsg
end

function putBeliefMessageUp!(tree::MetaBayesTree, edge, beliefMsg::LikelihoodMessage)
  # Blocks until data is available.
  put!(MetaGraphs.get_prop(tree.bt, edge, :upMsg), beliefMsg)
  return beliefMsg
end



"""
    $SIGNATURES

Based on a push model from child cliques that should have already completed their computation.
"""
getCliqInitUpMsgs(cliq::TreeClique) = getCliqueData(cliq).upInitMsgs

getInitDownMsg(cliq::TreeClique) = getCliqueData(cliq).downInitMsg

"""
    $SIGNATURES

Set cliques up init msgs.
"""
function setCliqUpInitMsgs!(cliq::TreeClique, childid::Int, msg::LikelihoodMessage)
  cd = getCliqueData(cliq)
  soco = getSolveCondition(cliq)
  lockUpStatus!(cd)
  cd.upInitMsgs[childid] = msg
  # TODO simplify and fix need for repeat
  # notify cliq condition that there was a change
  notify(soco)
  unlockUpStatus!(cd)
  #hack for mitigating deadlocks, in case a user was not already waiting, but waiting on lock instead
  sleep(0.1)
  notify(soco)
  nothing
end


"""
    $(SIGNATURES)

Set the upward passing message for This `cliql` in Bayes (Junction) tree.

Dev Notes
- TODO setUpMsg! should also set inferred dimension
"""
function setMsgUpThis!(cliql::TreeClique, msgs::LikelihoodMessage)
  # TODO change into a replace put!
  getCliqueData(cliql).upMsg = msgs
end


"""
    $(SIGNATURES)

Return the last up message stored in This `cliq` of the Bayes (Junction) tree.
"""
getMsgsUpThis(cliql::TreeClique) = getCliqueData(cliql).upMsg
getMsgsUpThis(btl::AbstractBayesTree, frontal::Symbol) = getUpMsgs(getClique(btl, frontal))


"""
    $(SIGNATURES)

Set the downward passing message for Bayes (Junction) tree clique `cliql`.
"""
function setMsgDwnThis!(cliql::TreeClique, msgs::LikelihoodMessage)
  getCliqueData(cliql).dwnMsg = msgs
end

function setMsgDwnThis!(csmc::CliqStateMachineContainer, msgs::LikelihoodMessage)
  setMsgDwnThis!(csmc.cliq, msgs)  # NOTE, old, csmc.msgsDown = msgs
end


"""
    $(SIGNATURES)

Return the last down message stored in `cliq` of Bayes (Junction) tree.
"""
getMsgsDwnThis(cliql::TreeClique) = getCliqueData(cliql).dwnMsg
getMsgsDwnThis(csmc::CliqStateMachineContainer) = getMsgsDwnThis(csmc.cliq) # NOTE, old csmc.msgsDown
getMsgsDwnThis(btl::AbstractBayesTree, sym::Symbol) = getMsgsDwnThis(getClique(btl, sym))

"""
    $SIGNATURES

Blocking call until `cliq` upInit processes has arrived at a result.
"""
function getCliqInitUpResultFromChannel(cliq::TreeClique)
  status = take!(getCliqueData(cliq).initUpChannel)
  @info "$(current_task()) Clique $(cliq.index), dumping initUpChannel status, $status"
  return status
end
