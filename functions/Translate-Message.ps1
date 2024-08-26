function Translate-Message {
    param (
        [string]$key,
        [string]$language
    )

    # Translation dictionary
    $translations = @{
        "en" = @{
            "SubtitleIssueDetected" = "Subtitle issue detected"
            "SyncStarted" = "Syncing of $languageName subtitles started."
            "SyncFinished" = "$languageName subtitles have been synced."
            "TranslationStarted" = "Translation of $sourceLanguageName to $targetLanguageName subtitles started."
            "TranslationFinished" = "Translation of subtitles finished."
            "FailedToParseLanguages" = "Failed to parse source and target languages"
            "SubtitlesMissing" = "Subtitles are either embedded or missing - cannot sync."
            "SubtitlesPartiallySynced" = "Subtitles synced with the exception of: episode"
        }
        "da" = @{
            "SubtitleIssueDetected" = "Undertekst problem opdaget"
            "SyncStarted" = "Synkronisering af $languageName undertekster startet."
            "SyncFinished" = "$languageName undertekster er blevet synkroniseret."
            "TranslationStarted" = "Oversættelse af $sourceLanguageName til $targetLanguageName undertekster startet."
            "TranslationFinished" = "Oversættelse af undertekster afsluttet."          
            "FailedToParseLanguages" = "Kunne ikke fortolke kilde- og målsprog"
            "SubtitlesMissing" = "Undertekster er enten indlejret eller mangler - kan ikke synkronisere."
            "SubtitlesPartiallySynced" = "Undertekster synkroniseret med undtagelse af: episode"
        }
        "de" = @{
            "SubtitleIssueDetected" = "Untertitelproblem erkannt"
            "SyncStarted" = "Synchronisierung der $languageName Untertitel gestartet."
            "SyncFinished" = "$languageName Untertitel wurden synchronisiert."
            "TranslationStarted" = "Übersetzung der $sourceLanguageName zu $targetLanguageName Untertitel gestartet."
            "TranslationFinished" = "Übersetzung der Untertitel abgeschlossen."
            "FailedToParseLanguages" = "Quell- und Zielsprache konnten nicht analysiert werden"
            "SubtitlesMissing" = "Untertitel sind entweder eingebettet oder fehlen - kann nicht synchronisieren."
            "SubtitlesPartiallySynced" = "Untertitel synchronisiert mit Ausnahme von: Episode"
        }
        "no" = @{
            "SubtitleIssueDetected" = "Undertekstproblem oppdaget"
            "SyncStarted" = "Synkronisering av $languageName undertekster startet."
            "SyncFinished" = "$languageName undertekster har blitt synkronisert."
            "TranslationStarted" = "Oversettelse av $sourceLanguageName til $targetLanguageName undertekster startet."
            "TranslationFinished" = "Oversettelse av undertekster fullført."
            "FailedToParseLanguages" = "Kunne ikke analysere kilde- og målspråk"
            "SubtitlesMissing" = "Undertekster er enten innebygd eller mangler - kan ikke synkroniseres."
            "SubtitlesPartiallySynced" = "Undertekster synkronisert med unntak av: episode"
        }
        "sv" = @{
            "SubtitleIssueDetected" = "Undertextproblem upptäckt"
            "SyncStarted" = "Synkronisering av $languageName undertexter startad."
            "SyncFinished" = "$languageName undertexter har synkroniserats."
            "TranslationStarted" = "Översättning av $sourceLanguageName till $targetLanguageName undertexter startad."
            "TranslationFinished" = "Översättning av undertexter avslutad."
            "FailedToParseLanguages" = "Misslyckades med att tolka käll- och målspråk"
            "SubtitlesMissing" = "Undertexter är antingen inbäddade eller saknas - kan inte synkronisera."
            "SubtitlesPartiallySynced" = "Undertexter synkroniserade med undantag för: avsnitt"
        }
        "es" = @{
            "SubtitleIssueDetected" = "Problema de subtítulos detectado"
            "SyncStarted" = "Sincronización de subtítulos en $languageName iniciada."
            "SyncFinished" = "Los subtítulos en $languageName se han sincronizado."
            "TranslationStarted" = "Traducción de subtítulos de $sourceLanguageName a $targetLanguageName iniciada."
            "TranslationFinished" = "Traducción de subtítulos finalizada."
            "FailedToParseLanguages" = "No se pudieron analizar los idiomas de origen y destino"
            "SubtitlesMissing" = "Los subtítulos están incrustados o faltan - no se pueden sincronizar."
            "SubtitlesPartiallySynced" = "Subtítulos sincronizados con la excepción de: episodio"
        }
        "fr" = @{
            "SubtitleIssueDetected" = "Problème de sous-titres détecté"
            "SyncStarted" = "Synchronisation des sous-titres en $languageName commencée."
            "SyncFinished" = "Les sous-titres en $languageName ont été synchronisés."
            "TranslationStarted" = "Traduction des sous-titres de $sourceLanguageName en $targetLanguageName commencée."
            "TranslationFinished" = "Traduction des sous-titres terminée."
            "FailedToParseLanguages" = "Impossible d'analyser les langues source et cible"
            "SubtitlesMissing" = "Les sous-titres sont soit intégrés, soit manquants - impossible de synchroniser."
            "SubtitlesPartiallySynced" = "Sous-titres synchronisés avec l'exception de : épisode"
        }
        "bg" = @{
            "SubtitleIssueDetected" = "Открит проблем със субтитрите"
            "SyncStarted" = "Синхронизацията на $languageName субтитри започна."
            "SyncFinished" = "$languageName субтитри са синхронизирани."
            "TranslationStarted" = "Преводът на субтитрите от $sourceLanguageName на $targetLanguageName започна."
            "TranslationFinished" = "Преводът на субтитрите завърши."
            "FailedToParseLanguages" = "Неуспешно разчитане на изходен и целеви език"
            "SubtitlesMissing" = "Субтитрите са вградени или липсват - не може да се синхронизират."
            "SubtitlesPartiallySynced" = "Субтитрите са синхронизирани с изключение на: епизод"
        }
        "it" = @{
            "SubtitleIssueDetected" = "Problema dei sottotitoli rilevato"
            "SyncStarted" = "Sincronizzazione dei sottotitoli in $languageName avviata."
            "SyncFinished" = "I sottotitoli in $languageName sono stati sincronizzati."
            "TranslationStarted" = "Traduzione dei sottotitoli da $sourceLanguageName a $targetLanguageName avviata."
            "TranslationFinished" = "Traduzione dei sottotitoli completata."
            "FailedToParseLanguages" = "Impossibile analizzare le lingue di origine e di destinazione"
            "SubtitlesMissing" = "I sottotitoli sono incorporati o mancanti - impossibile sincronizzare."
            "SubtitlesPartiallySynced" = "Sottotitoli sincronizzati con l'eccezione di: episodio"
        }
        "hy" = @{
            "SubtitleIssueDetected" = "Ենթավերնագիրների խնդիր հայտնաբերվել է"
            "SyncStarted" = "$languageName ենթավերնագրերի համաժամանակեցումը սկսվել է."
            "SyncFinished" = "$languageName ենթավերնագրերը համաժամանակեցված են."
            "TranslationStarted" = "$sourceLanguageName-ից $targetLanguageName ենթավերնագրերի թարգմանությունը սկսվել է."
            "TranslationFinished" = "Ենթավերնագրերի թարգմանությունը ավարտված է."
            "FailedToParseLanguages" = "Չհաջողվեց վերլուծել սկզբնական և նպատակային լեզուները"
            "SubtitlesMissing" = "Ենթավերնագրերը կա՛մ ներդրված են, կա՛մ բացակայում են՝ չի հաջողվել համաժամանակեցնել."
            "SubtitlesPartiallySynced" = "Ենթավերնագրերը համաժամանակեցված են, բացառությամբ՝ դրվագ"
        }
        "as" = @{
            "SubtitleIssueDetected" = "সাবটাইটেল সমস্যা চিহ্নিত হৈছে"
            "SyncStarted" = "$languageNameৰ সাবটাইটেলসমূহৰ চিঙ্ক্ৰোনাইজেচন আৰম্ভ হৈছে."
            "SyncFinished" = "$languageNameৰ সাবটাইটেলসমূহ চিঙ্ক্ৰোনাইজড হৈছে."
            "TranslationStarted" = "$sourceLanguageNameৰ পৰা $targetLanguageNameলৈ সাবটাইটেলসমূহৰ অনুবাদ আৰম্ভ হৈছে."
            "TranslationFinished" = "সাবটাইটেলসমূহৰ অনুবাদ সমাপ্ত হৈছে."
            "FailedToParseLanguages" = "উৎপত্তি আৰু লক্ষ্য ভাষাসমূহৰ বিশ্লেষণ বিফল হৈছে"
            "SubtitlesMissing" = "সাবটাইটেলসমূহ এম্বেড কৰা হৈছে বা অনুপস্থিত আছে - চিঙ্ক্ৰোনাইজ কৰিব নোৱাৰি."
            "SubtitlesPartiallySynced" = "সাবটাইটেলসমূহ ডাঙৰ কৰাৰ সময়ত সিঙ্ক্ৰোনাইজড হৈছে, সৰ্বভাৰতীয় বেতাৰ: অধ্যায়"
        }
        "ba" = @{
            "SubtitleIssueDetected" = "Титрҙарҙағы мәсьәлә асыҡланды"
            "SyncStarted" = "$languageName титрҙары синхронлаштырыла башланы."
            "SyncFinished" = "$languageName титрҙары синхронлаштырылды."
            "TranslationStarted" = "$sourceLanguageName-тан $targetLanguageName титрҙары тәржемә ителә башланы."
            "TranslationFinished" = "Титрҙарҙың тәржемәһе тамамланды."
            "FailedToParseLanguages" = "Тәржемә сығанаҡ һәм маҡсат телдәрен анализлау уңышһыҙ булды"
            "SubtitlesMissing" = "Титрҙар ендәшмәләре йәки юҡ - синхронлаштырыу мөмкин түгел."
            "SubtitlesPartiallySynced" = "Титрҙар синхронлаштырылды, тик эпизодтар юҡ"
        }
        "bn" = @{
            "SubtitleIssueDetected" = "সাবটাইটেল সমস্যা সনাক্ত করা হয়েছে"
            "SyncStarted" = "$languageName সাবটাইটেলগুলির সিঙ্ক্রোনাইজেশন শুরু হয়েছে."
            "SyncFinished" = "$languageName সাবটাইটেলগুলি সিঙ্ক্রোনাইজ করা হয়েছে."
            "TranslationStarted" = "$sourceLanguageName থেকে $targetLanguageName সাবটাইটেলের অনুবাদ শুরু হয়েছে."
            "TranslationFinished" = "সাবটাইটেলগুলির অনুবাদ শেষ হয়েছে."
            "FailedToParseLanguages" = "উৎস এবং লক্ষ্য ভাষা বিশ্লেষণে ব্যর্থ হয়েছে"
            "SubtitlesMissing" = "সাবটাইটেলগুলি এম্বেড করা হয়েছে বা অনুপস্থিত - সিঙ্ক্রোনাইজ করা যাবে না."
            "SubtitlesPartiallySynced" = "সাবটাইটেলগুলি সিঙ্ক্রোনাইজ করা হয়েছে ব্যতিক্রম সহ: পর্ব"
        }
        "bi" = @{
            "SubtitleIssueDetected" = "Ishiu blong subtitles I stap"
            "SyncStarted" = "Syncronising blong $languageName subtitles I stat."
            "SyncFinished" = "$languageName subtitles I bin sync."
            "TranslationStarted" = "Translating blong $sourceLanguageName to $targetLanguageName subtitles I stat."
            "TranslationFinished" = "Translation blong subtitles I finis."
            "FailedToParseLanguages" = "Fail blong analyze source mo target languages"
            "SubtitlesMissing" = "Subtitles I embedded o I lus - I no save sync."
            "SubtitlesPartiallySynced" = "Subtitles I sync but not all: episode"
        }
        "br" = @{
            "SubtitleIssueDetected" = "Kudennoù titloù zo bet kavet"
            "SyncStarted" = "Kregiñ zo bet graet gant sinkronizadur titloù $languageName."
            "SyncFinished" = "Titloù $languageName zo bet sinkronizet."
            "TranslationStarted" = "Kregiñ zo bet graet gant an droidigezh a $sourceLanguageName da $targetLanguageName titloù."
            "TranslationFinished" = "Troidigezh an titloù echu eo."
            "FailedToParseLanguages" = "C'hwitadennañ war an danvez yezhoù orin ha palez"
            "SubtitlesMissing" = "Titloù zo enlañket pe zo koll - ne c'haller ket sinkronizañ."
            "SubtitlesPartiallySynced" = "Titloù sinkronizet, nemet: rann"
        }
        "ch" = @{
            "SubtitleIssueDetected" = "Problemu gi subtitulos"
            "SyncStarted" = "I Sinchroniza $languageName subtitulos na gaigeha."
            "SyncFinished" = "$languageName subtitulos siha na gaige gi sinchronize."
            "TranslationStarted" = "I Sinchchonza $sourceLanguageName para $targetLanguageName subtitulos na gaigeha."
            "TranslationFinished" = "Manmanao i translation gi subtitulos."
            "FailedToParseLanguages" = "Kapot I nininiyi gi $sourceLanguageName yan $targetLanguageName"
            "SubtitlesMissing" = "Subtitulos gaige gi embedded pat manca – Siña ti sinchronize."
            "SubtitlesPartiallySynced" = "Subtitulos siha na gaige gi partial sinchronization: episode"
        }
        "ce" = @{
            "SubtitleIssueDetected" = "Субтитрта хилар"
            "SyncStarted" = "$languageName субтитрта синхронизаран дуьнца."
            "SyncFinished" = "$languageName субтитрта синхронизаран оьша."
            "TranslationStarted" = "$sourceLanguageName лахьан $targetLanguageName лаьттан субтитрта тарад."
            "TranslationFinished" = "Субтитрта таржам оьша."
            "FailedToParseLanguages" = "Т1еьхьахьарали хьажор наьшх лахарни т1ехьарсар дуьцат1о."
            "SubtitlesMissing" = "Субтитрта хадона, хилара – синхронизарийн дуьцеташ бу."
            "SubtitlesPartiallySynced" = "Субтитрта синхронизарян т1айпе хилаьжара дуьцанара: episode"
        }
        "ny" = @{
            "SubtitleIssueDetected" = "Zovuta pa subtitles"
            "SyncStarted" = "Kuyamba kwa sync ya $languageName ma subtitles."
            "SyncFinished" = "$languageName ma subtitles akwaniritsidwa."
            "TranslationStarted" = "Chiyambi cha kumasulira kwa $sourceLanguageName kupita $targetLanguageName ma subtitles."
            "TranslationFinished" = "Kumasulira kwa subtitles kwatha."
            "FailedToParseLanguages" = "Kulephera kutanthauzira chinenero choyambira ndi chinenero cholingana"
            "SubtitlesMissing" = "Ma subtitles akuphatikizidwa kapena kusowa - sangathe kugwirizanitsidwa."
            "SubtitlesPartiallySynced" = "Ma subtitles agwirizanitsidwa koma pang'ono: episode"
        }
        "cv" = @{
            "SubtitleIssueDetected" = "Çулислă çихтĕн"
            "SyncStarted" = "$languageName çулислă сĕнчен вăхăтпа çинхронланать."
            "SyncFinished" = "$languageName çулислă çинхронланать."
            "TranslationStarted" = "$sourceLanguageName тăсăртан $targetLanguageName çулислă тарихни."
            "TranslationFinished" = "Çулислă тарихланать."
            "FailedToParseLanguages" = "Çырать $sourceLanguageName-ро $targetLanguageName не зачетать."
            "SubtitlesMissing" = "Çулислă хала чухӑнăма пулăт - теç çинхронларĕ."
            "SubtitlesPartiallySynced" = "Çулислă çинхронланать аннан чунлатăн: эпизод"
        }
        "kw" = @{
            "SubtitleIssueDetected" = "Teusans drehevel subtitles"
            "SyncStarted" = "$languageName subtitles yw syncronised."
            "SyncFinished" = "$languageName subtitles a syncronised."
            "TranslationStarted" = "$sourceLanguageName a syncronised der $targetLanguageName subtitles."
            "TranslationFinished" = "Subtitles yw wosa tevethys."
            "FailedToParseLanguages" = "Kuspary dreineans source ha gweltek languages."
            "SubtitlesMissing" = "Subtitles yw embedys ynno, pe fawyk - ny a all syncronised."
            "SubtitlesPartiallySynced" = "Subtitles yw syncronised an peth namyn: episode"
        }
        "co" = @{
            "SubtitleIssueDetected" = "Problema di sottotitoli"
            "SyncStarted" = "Syncing di sottotitoli $languageName iniziato."
            "SyncFinished" = "I sottotitoli $languageName sò stati sincronizati."
            "TranslationStarted" = "A traduzzione di $sourceLanguageName in $targetLanguageName sottotituli hà iniziatu."
            "TranslationFinished" = "A traduzzione di sottotituli hè finita."
            "FailedToParseLanguages" = "Mancu capisce e lingue di origine è di destinazione"
            "SubtitlesMissing" = "I sottotituli sò incorporati o mancanu - ùn ponu micca sincronizà."
            "SubtitlesPartiallySynced" = "Sottotituli sincronizati cù l'eccezzioni di: episodiu"
        }
        "cr" = @{
            "SubtitleIssueDetected" = "ᐱᑳᓇᐁᐧ ᒧᐧᐢᑳᐠ"
            "SyncStarted" = "$languageName ᐱᑳᓇᐁᐧᐠ ᐃᑭᔭᐦᐄᑭᓇᐁᐧᑯᐃᐧᓂᐤ"
            "SyncFinished" = "$languageName ᐃᑭᔭᐦᐄᑭᓇᐁᐧᐠ ᐊᑭᒋᒥᐢᑯᓇᒣᐠ"
            "TranslationStarted" = "$sourceLanguageName ᐃᑭᔭᐦᐄᑭᓇᐁᐧ ᐱᑳᓇᐁᐧᐠ ᐅᐱᓀᓱᓂᓂᑯᐃᐧ $targetLanguageName"
            "TranslationFinished" = "ᐊᒋᒥᐢᑯᓇᒣᐠ"
            "FailedToParseLanguages" = "ᑌᐦᑯ ᐋᐦᑲᓇᐁᐧ ᑎᒧᐁᒣᓇᐁᐧᒣᐧᑎᓂᐧᐃᐧᓂᐤ"
            "SubtitlesMissing" = "ᐱᑳᓇᐁᐧᐠ ᐋᒋᐧᔭᓯᐠ"
            "SubtitlesPartiallySynced" = "ᐱᑳᓇᐁᐧᐠ ᐅᐢᑌᒋᑯᑎᔥ ᐋᔅᑭᓂᐢᑎᐃᐧᐃᐧᔭᑯᓇᒣᐠ"
        }
    }

    if ($translations.ContainsKey($language) -and $translations[$language].ContainsKey($key)) {
        return $translations[$language][$key]
    } else {
        return $translations["en"][$key]  # Fallback to English if translation is not found
    }
}
