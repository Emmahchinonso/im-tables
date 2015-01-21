_ = require 'underscore'

CoreView = require '../../core-view'
CoreModel = require '../../core-model'
Collection = require '../../core/collection'
Templates = require '../../templates'

ClassSet = require '../../utils/css-class-set'

# The four dialogues of the apocalypse
AppendPicker = require './append-from-selection'
CreatePicker = require './create-from-selection'
AppendFromPath = require './append-from-path'
CreateFromPath = require './create-from-path'

require '../../messages/lists'

class PathModel extends CoreModel

  defaults: ->
    path: null
    type: null
    displayName: null
    typeName: null

  constructor: (path) ->
    super()
    @set
      id: (path.toString() + '.id')
      path: path.toString()
      type: path.getType().name

    path.getDisplayName().then (name) =>
      @set displayName: name
    path.getType().getDisplayName().then (name) =>
      @set typeName: name

class Paths extends Collection

  model: PathModel

class SelectableNode extends CoreView

  parameters: ['query', 'model', 'showDialogue']

  tagName: 'li'

  modelEvents: -> 'change:displayName change:typeName': @reRender

  stateEvents: -> 'change:count': @reRender

  Model: PathModel

  template: Templates.template 'list-dialogue-button-node'

  events: -> click: 'openDialogue'

  initialize: ->
    super
    console.log 'summarising', @model.get 'path'
    @query.summarise @model.get 'id'
          .then ({stats}) => @state.set count: stats.uniqueValues

  openDialogue: ->
    args = {@query, path: @model.get('id')}
    @showDialogue args

module.exports = class ListDialogueButton extends CoreView

  tagName: 'div'

  className: 'btn-group list-dialogue-button'

  template: Templates.template 'list-dialogue-button'

  parameters: ['query', 'selected']

  initState: ->
    @state.set action: 'create'

  stateEvents: ->
    'change:action': @setActionButtonState

  events: ->
    'click .im-create-action': @setActionIsCreate
    'click .im-append-action': @setActionIsAppend
    'click .im-pick-items': @startPicking

  initialize: ->
    super
    @initBtnClasses()
    @paths = new Paths
    # Reversed, because we prepend them in order to the menu.
    @query.getQueryNodes().reverse().forEach (n) => @paths.add new PathModel n

  getData: -> _.extend super, @classSets, paths: @paths.toJSON()

  postRender: ->
    menu = @$ '.dropdown-menu'
    @paths.each (model, i) =>
      showDialogue = (args) => @showPathDialogue args
      node = new SelectableNode {@query, model, showDialogue}
      @renderChild "path-#{ i }", node, menu, 'prepend'

  setActionIsCreate: (e) ->
    e.stopPropagation()
    e.preventDefault()
    @state.set action: 'create'

  setActionIsAppend: (e) ->
    e.stopPropagation()
    e.preventDefault()
    @state.set action: 'append'

  showDialogue: (Dialogue, args) ->
    dialogue = new Dialogue args
    @renderChild 'dialogue', dialogue
    success = (list) => @trigger "list:#{ action }", list
    failure = (e) => @trigger "failure:#{ action }", e
    dialogue.show().then success, failure

  showPathDialogue: (args) ->
    action = @state.get 'action'
    Dialogue = switch action
      when 'append' then AppendFromPath
      when 'create' then CreateFromPath
      else throw new Error "Unknown action: #{ action }"
    @showDialogue Dialogue, args

  startPicking: ->
    action = @state.get 'action'
    args = {collection: @selected, service: @query.service}
    Dialogue = switch action
      when 'append' then AppendPicker
      when 'create' then CreatePicker
      else throw new Error "Unknown action: #{ action }"
    @showDialogue Dialogue, args

  setActionButtonState: ->
    action = @state.get 'action'
    @$('.im-create-action').toggleClass 'active', action is 'create'
    @$('.im-append-action').toggleClass 'active', action is 'append'

  initBtnClasses: ->
    @classSets = {}
    @classSets.createBtnClasses = new ClassSet
      'im-create-action': true
      'btn btn-default': true
      active: => @state.get('action') is 'create'
    @classSets.appendBtnClasses = new ClassSet
      'im-append-action': true
      'btn btn-default': true
      active: => @state.get('action') is 'append'
