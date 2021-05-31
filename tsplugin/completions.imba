
import * as util from './util'
import Context from './context'

import {Sym,CompletionTypes as CT} from '../document'


const Globals = "global imba module window document exports console process parseInt parseFloat setTimeout setInterval setImmediate clearTimeout clearInterval clearImmediate globalThis isNaN isFinite __dirname __filename".split(' ')

const Keywords = "and await begin break by case catch class const continue css debugger def get set delete do elif else export extends false finally for if import in instanceof is isa isnt let loop module nil no not null of or require return self static super switch tag then this throw true try typeof undefined unless until var when while yes".split(' ')

###
CompletionItemKind {
		Text = 0,
		Method = 1,
		Function = 2,
		Constructor = 3,
		Field = 4,
		Variable = 5,
		Class = 6,
		Interface = 7,
		Module = 8,
		Property = 9,
		Unit = 10,
		Value = 11,
		Enum = 12,
		Keyword = 13,
		Snippet = 14,
		Color = 15,
		Reference = 17,
		File = 16,
		Folder = 18,
		EnumMember = 19,
		Constant = 20,
		Struct = 21,
		Event = 22,
		Operator = 23,
		TypeParameter = 24
	}
###

export class Completion
	
	data = {}
	label = {}

	constructor symbol, context, options = {}
		#cache = {}
		#context = context
		#options = options
		sym = #symbol = symbol
		weight = 0
		
		item = {data: data, label: label, sortText: ""}
		load(symbol,context,options)
		kind = options.kind if options.kind
	
		setup(symbol)
		triggers options.triggers
		
	def load symbol, context, options = {}
		yes
		self
		
	def setup sym
		Object.assign(item,sym)
		
	get id
		return #nr if #nr >= 0
		#nr = #context.items.indexOf(self)
	
	get checker
		#context.checker
		
	get program
		checker.program

	get #type
		#symbol.type or #symbol.type_
		
	get importInfo
		null
		
	get weight
		#weight or #options.weight
	
	set weight val
		#weight = val
		
	def resolveImportInfo
		let info = importInfo
		return unless info
		let alias = info.importName or info.name
		let name = info.importKind == 1 ? 'default' : alias
		let edits = doc.createImportEdit(info.source,name,alias)
		
		if edits.alias
			item.insertText = edits.alias
			ns = edits.alias

		elif edits.changes.length
			item.additionalTextEdits = edits.changes
		self
		
	get doc
		#context.doc
		
	def triggers chars = ''
		return self unless chars
		let list = item.commitCharacters ||= []
		for chr of chars
			list.push(chr) unless list.indexOf(chr) >= 0
		return self
	
	def #resolve
		if #resolved =? yes
			# console.log 'resolving item',self
			resolve!
		return item
	
	def resolve
		self

	get completion
		self
		
	get source
		null

	set kind kind
		item.kind = kind
	
	get kind
		item.kind

	set name val do label.name = val
	get name do label.name

	set detail val
		item.detail = val

	set ns val
		if val isa Array
			val = val[0]
		
		if val and val.text
			val = val.text

		label.qualifier = val
	
	get ns
		label.qualifier
	
	set documentation val
		item.documentation = val

	set sourceFile val
		if #sourceFile = val
			sourcePath = val.path
			
	set sourcePath val
		if #sourcePath = val
			data.source = val
			ns = util.normalizeImportPath(#context.file.fileName,val)
			
	get sourceFile
		#sourceFile
		
	get exportInfo
		null
	
	get uniqueName
		#uniqueName or item.insertText or name

	def serialize stack = {}
		let o = #options
		let key = uniqueName
		
		if stack[key]
			return null
			
		if o.startsWith
			return null unless key.indexOf(o.startsWith) == 0
		
		stack[key] = self
		
		if o..commitCharacters
			item.commitCharacters = o.commitCharacters
		if #weight != undefined
			item.sortText = util.zerofill(#weight)
			data.nr = id
		# item.data.id ||= "{#context.file.id}|{#context.id}|{id}"
		return item
		
	def resolveImportEdits
		let info = exportInfo
		if info
			let specifier = checker.getModuleSpecifierForBestExportInfo(info)
			let path = specifier.moduleSpecifier
			
			let alias = data.name or info[0].importName
			let name = specifier.importKind == 1 ? 'default' : alias

			let edits = doc.createImportEdit(path,name,alias)
			
			if edits.changes.length
				item.additionalTextEdits = edits.changes
				ns = "from '{path}'"

			# console.log edits.changes,info,specifier,item,self

		self

export class SymbolCompletion < Completion
	def setup sym
		let cat = #options.kind
		let par = sym.parent
		let tags = sym.imbaTags or {}
		let o = #options
		let f = sym.flags
		name = sym.imbaName
		data.kind = cat
		
		# let pname = sym.parent..escapedName
		if cat == 'styleprop'
			#uniqueName = name
			if tags.alias
				item.insertText = ns = tags.alias
			elif tags.proxy
				ns = tags.proxy
			triggers ':@.'

		elif cat == 'styleval'
			weight = name[0] == '-' ? 2000 : 1000
			triggers ' '
			let type = sym.parent.escapedName.slice(4)
			let desc = sym.getDocumentationComment! or []
			if desc[0] and desc[0].text
				ns = desc[0].text
			
			if type == 'color'
				kind = 15
				detail = tags.color
				
		elif cat == 'stylemod'
			ns = tags.detail
			triggers ': '
			
	
	def resolve
		let details = checker.getSymbolDetails(sym)
			
		if let docs = details.documentation
			item.documentation = global.session.mapDisplayParts(docs,checker.project)
		if let dp = details.displayParts
			item.detail = global.ts.displayPartsToString(dp)
		# documentation: this.mapDisplayParts(details.documentation, project),
		# tags: this.mapJSDocTagInfo(details.tags, project, useDisplayParts),
		# item.documentation = details.documentation
		# item.documentation = details.documentation
		self

export default class Completions
	
	constructor script, pos, prefs
		self.script = script
		self.pos = pos
		self.prefs = prefs
		self.ls = ls or script.ls
		
		#prefix = ''
		#added = {}
		#uniques = new Map
		
		items = []
		resolve!
		
	get checker
		# should we choose configured project or?
		#checker ||= script.getTypeChecker!
		
	get triggerCharacter
		prefs.triggerCharacter
			
	def resolve
		ctx = script.doc.getContextAtOffset(pos)
		tok = ctx.token
		flags = ctx.suggest.flags
		util.log('resolveCompletions',self,ctx,tok)
		
		if tok.match('identifier')
			prefix = ctx.before.token

		prefixRegex = new RegExp("^{prefix}","i")
		
		if flags & CT.TagName
			util.log('resolveTagNames',ctx)
			add('tagnames',kind: 'tagname')
			
		if flags & CT.StyleModifier
			add checker.cssmodifiers, kind: 'stylemod'
			
		if flags & CT.StyleSelector
			add checker.props('ImbaHTMLTags',yes), kind: 'stylesel'
		
		if flags & CT.StyleProp
			add checker.props('$cssrule$'), kind: 'styleprop'
			
		if flags & CT.StyleValue
			add 'stylevalue', kind: 'styleval'

		
		if triggerCharacter == '<' and ctx.after.character == '>'
			add completionForItem({
				commitCharacters: [' ','<','=']
				filterText: ''
				preselect: yes
				sortText: "0000"
				kind: 'snippet'
				textEdit: {start: pos, length: 1, newText: ''}
				label: {name: ' '}
			})
		self
		
	def stylevalue o = {}
		let node = ctx.group.closest('styleprop')
		let name = node..propertyName
		let before = ctx..before..group
		let nr = before ? (before.split(' ').length - 1) : 0
		let symbols = checker.getStyleValues(name,nr)
		add symbols,o
		util.log('stylevalue',ctx.before,nr,symbols)
		# only if first argument
		if nr == 0
			add checker.props('$cssmodule$.css$globals'),o
		self
		
	def tagnames o = {}
		let html = checker.props('HTMLElementTagNameMap')
		add(html,o)
		
	def completionForItem item, opts = {}
		if item isa Completion
			return item
		
		if item.#tsym
			item = item.#tsym

		let entry = #uniques.get(item)
		return entry if entry

		if item isa global.SymbolObject
			entry = new SymbolCompletion(item,self,opts)
		elif item.#symbolFile
			entry = new WorkspaceSymbolCompletion(item,self,opts)
		elif item isa Sym
			entry = new SymCompletion(item,self,opts)
		elif item.hasOwnProperty('exportKind')
			entry = new AutoImportCompletion(item,self,opts)
		elif item.label
			entry = new Completion(item,self,opts)

		#uniques.set(item,entry)
		return entry
		
	def add type, options = {}
		
		if type isa Completion
			items.push(type) unless items.indexOf(type) >= 0
			return self
		
		if type isa Array
			for item in type
				add(completionForItem(item,options))
			return self

		return self if #added[type] 
		#added[type] = []
		
		let t = Date.now!
		let results = self[type](options)
		
		util.log "called {type}",Date.now! - t

		if results isa Array
			for item in results
				add(completionForItem(item,options))
				# items.push(completionForItem(item))
			util.log "added {results.length} {type} in {Date.now! - t}ms"

		#added[type] = results or true
		return self

	def serialize
		let entries = []
		let stack = {}
		# util.time(&,'serializing') do
		for item in items
			let entry = item.serialize(stack)
			entries.push(entry) if entry

		# devlog 'serialized',entries,items
		return entries
		
	def find item
		items.find do $1.name == item