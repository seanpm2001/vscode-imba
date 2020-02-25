import {TAG_NAMES,TAG_TYPES,EVENT_MODIFIERS} from './constants'
import {CompletionItemKind,SymbolKind,InsertTextFormat,CompletionItem} from 'vscode-languageserver-types'
import {convertCompletionKind} from './utils'

import {tags,globalAttributes} from './html-data.json'

var globalEvents = for item in globalAttributes when item.name.match(/^on\w+/)
	item


for tagItem in tags
	tags[tagItem.name] = tagItem

export class Entities

	def constructor program
		@program = program
	
	def getTagNameCompletions o = {}

		let items\CompletionItem[] = []
		for own name,ctor of TAG_NAMES
			items.push {
				label: name.replace('_',':'),
				kind: CompletionItemKind.Field,
				sortText: name
				data: { resolved: true }
			}
			
		for item in items
			if o.autoclose
				item.insertText = item.label + '$1>$0'
				item.insertTextFormat = InsertTextFormat.Snippet

		return items

	def getCompletionsForContext uri,pos,ctx
		let items\CompletionItem[] = []
		let entry\CompletionItem

		let mode =  ctx.stack[0]
		if mode == 'tag'
			items = @getTagNameCompletions()

		elif mode == 'event'
			for item in globalEvents
				entry =
					label: ':' + item.name.slice(2)
					sortText: item.name.slice(2)
					kind: CompletionItemKind.Field
				items.push(entry)

		elif mode == 'modifier'
			for item in EVENT_MODIFIERS
				items.push({
					label: item.name,
					kinds: CompletionItemKind.Enum,
					detail: item.description or ''
				})

		elif mode == 'attr'
			for item in globalAttributes
				let desc = item.description
				if item.name.match(/^on\w+/)
					continue
					entry = {
						label: ':' + item.name.slice(2)
						sortText: item.name.slice(2)
						kind: CompletionItemKind.Field
					}
				else
					entry = {label: item.name}

				if desc
					entry.detail = desc.value

				items.push(entry)

			if let tagSchema = tags[ctx.tagName]
				for item in tagSchema.attributes
					items.push(label: item.name)

		for item in items
			item.kind ||= CompletionItemKind.Field
			item.data ||= { resolved: true }

			if typeof item.kind == 'string'
				item.kind = convertCompletionKind(item.kind)

			if item.label[0] == ':'
				item.kind = CompletionItemKind.Function
				item.sortText = item.label.slice(1)

			if mode == 'event' and item.label[0] == ':'
				item.insertText = item.label.slice(1)
				item.commitCharacters = ['.']

		return items


	def registerTag
		[]

	def propertiesForTag name
		[]