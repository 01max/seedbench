require 'rails_helper'

RSpec.describe Providers::C411::EbookNaming do
  it 'keeps separate listing, payload and torrent grammars' do
    names = described_class.call(title: 'L’été retrouvé', author: 'Alice Martin', language: 'fr', format: 'epub')
    expect(names.release).to eq('L.été.retrouvé.Alice.Martin.FRENCH.[EPUB]-NOTAG')
    expect(names.payload).to eq('L.été.retrouvé.Alice.Martin.FRENCH-NOTAG.epub')
    expect(names.torrent).to eq('L.été.retrouvé.Alice.Martin.FRENCH.NOTAG.torrent')
  end

  it 'preserves an explicitly reviewed known team and format' do
    names = described_class.from_release(name: 'Titre.Tome.2.Auteur.FRENCH.[PDF]-Source', format: 'pdf')
    expect(names.payload).to eq('Titre.Tome.2.Auteur.FRENCH-Source.pdf')
    expect(names.torrent).to eq('Titre.Tome.2.Auteur.FRENCH.Source.torrent')
  end

  it 'normalizes the legacy NOTAG and video suffix without repeating it' do
    [ 'Titre.Auteur.FRENCH.NOTAG.VFF-NOTAG.[EPUB]-NOTAG',
      'Titre.Auteur.FRENCH.[EPUB].NOTAG.VFF-NOTAG', 'Titre.Auteur.FRENCH.[EPUB]-NOTAG-NOTAG' ].each do |name|
      names = described_class.from_release(name: name, format: 'epub')
      repeated = described_class.from_release(name: names.release, format: 'epub')
      expect(repeated).to eq(names)
      expect(names.release).to eq('Titre.Auteur.FRENCH.[EPUB]-NOTAG')
      expect(names.payload.scan('NOTAG').size).to eq(1)
      expect(names.torrent).to end_with('.NOTAG.torrent')
    end
  end

  it 'rejects unsafe, mismatched, oversized and video names' do
    [ '../Book.[EPUB]-NOTAG', 'Book.[PDF]-NOTAG', 'Book.VFF.[EPUB]-NOTAG', 'Book.vff.[EPUB]-NOTAG', 'Book.Author.[EPUB]-NOTAG', 'Book.FRENCH.[EPUB]-NOTAG', "#{'A' * 240}.[EPUB]-NOTAG" ].each do |name|
      expect { described_class.from_release(name: name, format: 'epub') }.to raise_error(described_class::InvalidName)
    end
  end

  it 'does not invent missing authors or French-language evidence' do
    expect { described_class.call(title: 'Book', author: '', language: 'fr', format: 'epub') }.to raise_error(described_class::InvalidName)
    expect { described_class.call(title: 'Book', author: 'Author', language: 'en', format: 'epub') }.to raise_error(described_class::InvalidName)
  end
end
