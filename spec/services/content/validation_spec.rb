require 'rails_helper'

RSpec.describe Content::Validation do
  let(:policy) { Providers::C411::EbookContent }
  let(:values) { policy::FIELDS.index_with { |field| "Value #{field}" }.merge('cover' => 'https://images.invalid/cover.png') }
  let(:expected) { values.except('cover').merge('format' => 'EPUB') }
  let(:body) { policy.assemble(values: values) }
  let(:nfo) { described_class::NFO_LABELS.map { |field| "#{I18n.t("content.nfo.#{field}")} : #{expected.fetch(field)}" }.join("\n") }

  def errors(bbcode: body, nfo_body: nfo)
    described_class.call(bbcode: bbcode, nfo: nfo_body, expected: expected, cover_url: values['cover']).pluck(:code)
  end

  it 'accepts matching facts and the exact selected hosted cover' do
    expect(errors).to be_empty
  end

  it 'rejects changed factual fields and required NFO values' do
    expect(errors(bbcode: body.sub('Value author', 'Wrong author'))).to include('fact_mismatch')
    expect(errors(nfo_body: nfo.sub('EPUB', 'PDF'))).to include('nfo_field')
    expect(errors(nfo_body: '')).to include('nfo_field')
  end

  it 'ignores surrounding NFO whitespace while still rejecting different facts' do
    expect(errors(nfo_body: nfo.sub('Value author', "\t Value author \t"))).to be_empty
    expect(errors(nfo_body: nfo.sub('Value author', "Different author \t"))).to include('nfo_field')
  end

  it 'rejects missing, duplicate, or reordered template labels' do
    expect(errors(bbcode: body.sub('[b]Langue :[/b]', '[b]Language :[/b]'))).to include('template')
    expect(errors(bbcode: body + 'Auteur(s) :')).to include('template')
    expect(errors(bbcode: body.sub('Auteur(s) :', 'TEMP :').sub('Éditeur :', 'Auteur(s) :').sub('TEMP :', 'Éditeur :'))).to include('template')
  end

  it 'rejects unsafe markup even inside prose' do
    expect(errors(bbcode: body.sub('Value presentation', '[url=javascript:alert(1)]unsafe[/url]'))).to include('invalid_attribute')
    expect(errors(bbcode: body.sub('Value presentation', '<script>alert(1)</script>'))).to include('unsafe_html')
    expect(errors(bbcode: body.sub('https://images.invalid/cover.png', 'https://other.invalid/cover.png'))).to include('cover')
  end

  it 'rejects fabricated page counts and altered optional edition facts' do
    expect(errors(nfo_body: nfo + "\nPages du PDF : 999")).to include('nfo_field')
    expect(errors(nfo_body: nfo + "\nÉditeur : Wrong publisher")).to include('nfo_field')
  end

  it 'allows full manual presentation edits while preserving factual checks' do
    expect(errors(bbcode: body.sub('Value presentation', 'Prose rédigée directement dans le BBCode.'))).to be_empty
  end

  it 'accepts the documented English NFO labels without weakening factual checks' do
    english = nfo.sub('Titre :', 'Title :').sub('Auteur(s) :', 'Author / illustrator :').sub('Langue :', 'Language :')
      .sub('Fichier(s) :', 'Content files :').sub('Taille :', 'Payload size :')
    expect(errors(nfo_body: english)).to be_empty
    expect(errors(nfo_body: english.sub('EPUB', 'PDF'))).to include('nfo_field')
  end
end
