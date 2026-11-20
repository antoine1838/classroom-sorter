# Politique de sécurité

## Versions prises en charge

Les correctifs de sécurité ciblent la dernière version publiée de **Plan de
classe** ainsi que la branche `main`. Les versions antérieures ne sont pas
maintenues séparément : mettez l'application à jour avant de vérifier si un
problème est toujours présent.

## Signaler une vulnérabilité

N'ouvrez pas de rapport public contenant des détails exploitables.

Utilisez le formulaire GitHub
[**Report a vulnerability**](https://github.com/antoine1838/classroom-sorter/security/advisories/new).
Il crée un brouillon d'avis de sécurité visible uniquement par le déclarant et
les mainteneurs autorisés.

Les rapports peuvent être rédigés en français ou en anglais. Merci d'indiquer,
dans le canal privé :

- la version et la plateforme concernées ;
- l'impact attendu et les conditions nécessaires à l'exploitation ;
- des étapes de reproduction minimales ;
- une preuve de concept utilisant exclusivement des données fictives ;
- toute piste de correction ou mesure d'atténuation connue.

Ne joignez jamais de vrais noms, notes ou informations d'élèves. N'envoyez pas
non plus de keystore, mot de passe, jeton GitHub ou identifiant Google Play.

## Délais indicatifs

Le projet vise à :

- accuser réception sous trois jours ouvrés ;
- fournir une première qualification sous sept jours ouvrés ;
- convenir ensuite d'un calendrier de correction et de divulgation selon la
  gravité et la complexité.

Ces délais sont des objectifs, pas une garantie. Si le rapport est accepté, le
mainteneur informera le déclarant de l'avancement jusqu'à la publication du
correctif.

## Périmètre

Sont notamment pertinents :

- la lecture et l'écriture des fichiers `.planclasse` et des PDF ;
- la persistance locale, les sauvegardes et la confidentialité des données
  d'élèves ;
- les permissions et configurations Android, iOS, Web et bureau ;
- la chaîne de build, la signature et les workflows de release ;
- une dépendance permettant d'attaquer l'application dans un scénario réaliste.

L'application ne possède ni compte utilisateur ni serveur applicatif. Les
éléments suivants sont hors périmètre sauf contournement supplémentaire d'une
protection de l'application :

- accès physique à un appareil déjà déverrouillé ou à un système déjà
  compromis, rooté ou jailbreaké ;
- fichier ou PDF que l'utilisateur a volontairement exporté et partagé ;
- version ancienne qui ne reproduit plus le problème après mise à jour ;
- ingénierie sociale sans vulnérabilité technique du projet.

## Recherche responsable

N'effectuez des tests que sur vos propres appareils, fichiers et comptes.
Évitez toute interruption de service, destruction de données, accès aux
secrets CI ou atteinte à la vie privée. Laissez au projet un délai raisonnable
pour corriger le problème avant toute publication et coordonnez la divulgation
avec le mainteneur.

Les correctifs sont annoncés dans les
[releases GitHub](https://github.com/antoine1838/classroom-sorter/releases) et,
le cas échéant, distribués via la mise à jour de l'application.
