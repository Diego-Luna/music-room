
#  Music Room - Project Overview

Un resumen del projecto de 42, un mapa de ruta para el desarrollo de la aplicación móvil, web y backend.

## Resumen del Proyecto (Project Summary)
The main objective of the "Music Room" project is the creation of a complete mobile solution focused on music and user experience. It aims to tackle all the concepts necessary to the creation of a mobile, connected, and collaborative application taking into account the constraints of a real product.

### Mandatory Features (Requisitos Obligatorios)
- **User Accounts:** Users must create an account when running the application for the first time. Registration options must include mail/password or a social network account (Facebook or Google).
- **Core Services:** The application must provide access to at least 2 out of the following 3 functions:
  1. **Music Track Vote:** Live music chain with vote. Users can suggest or vote for tracks, and if a track gets many votes, it goes up in the list and is played earlier.
  2. **Music Control Delegation:** Music control delegation. Users can choose to give the music control to different friends. A license management specific to each device attached to the account must be integrated.
  3. **Music Playlist Editor:** Real-time multi-user playlist edition. It allows users to collaborate with friends to create playlists in real-time.
- **Backend & API:** All the service data will be stored on the back-end side, which is the reference. We will use a REST API and JSON as the exchange format.
- **Security:** Authenticated users must only have access to their own data, not to other users' data. We must implement mechanisms to protect users, and any action on the mobile application must generate logs on the back-end.

### Bonus Features (Para después del MVP)
*Solo se evaluarán si la parte obligatoria es perfecta.*
- **Multi-platform support:** Support various platforms and make the service web "responsive" to adapt to any screen size.
- **IoT Reflection:** Implement a mechanism such as IBeacon for physical events.
- **Subscriptions:** Offer users the choice between a free limited subscription and unlimited paid ones, allowing them to switch between the two.
- **Offline Mode:** Implement a mechanism that allows users to enjoy the application offline when there is no mobile service. This requires a synchronization plan to handle conflicts and obsolete data.

---

## Tech Stack & [[Arquitectura REST]] 

Para resolver este proyecto en **maximo 2 meses** y cubrir los bonus multiplataforma, lo mejor es usar **Flutter** para el frontend.

### Frontend (Flutter App)
- **Framework:** Flutter (Compila y mismo base of code to iOS, Android y Web nativamente)
- **State Management:** `Provider` 
- **API Networking:** `dio` (REST clasico).
- **Real-Time Collaboration:** `web_socket_channel` (Para el Editor de Playlist y los Votos en vivo) *aprender*.
- **Authentication:** `firebase_auth`, `google_sign_in`, `flutter_facebook_auth`, `flutter_secure_storage`
- **Offline Storage (Para Bonus):** `hive_ce` (Base de datos local ultrarrápida para manejar el caché cuando no hay red) *aprender*.
- **Security Logs:** `device_info_plus` & `package_info_plus` (Para enviar los logs de plataforma exigidos).
- **Subscriptions** con `flutter_stripe` (El paquete soporta las 3 plataformas necesarias)


## Para la calificaicon del projecto

### CD/CI
- **Build** para IOS y andorid en la nube  con `Codemagic` *learn*
- **Buidl** GitHub Actions? *its possible*
- **obligatorio** Send to the Google Play 
> **obligatorio** Send to App Store  ($ 100 usd)


## Next Steps
- [ ] Inicializar repositorio de Git y projecto para el manejo de tiempo
- [ ] [[Arquitectura REST]] : Hablar de la organisacion de la API y el la estrcutia de tados .
- [ ] Enfocarse en conseguir el MVP **(1 - 4 semanas)**
	- [ ] **(1 - 2 semanas)** Primera seccion
		- [ ] User Accounts
		- [ ] Core Services
			- [ ] Music Track Vote
			- [ ] Music Control Delegation
	- [ ]  **(1 - 2 semanas)** Segunda seccion
		- [ ] CD / CI (para el proyecto configuracion WEB/ APP)
		- [ ] Idratacion de la API
		- [ ] Music Playlist Editor (WebSockets)
- [ ] Bonus  **(1 - 2 semanas)**
	- [ ] **poca configuraicon** Multi-platform support 
	- [ ] **IoT Reflection**
	- [ ] **Subscriptions** con stripe
	- [ ] **Offline Mode**
- [ ] Evaluacion (1 semana)
	- [ ] Its posible to
- [ ]  Tiempo maximo 8 semanas, 18 de mayo tiempo maximo

### Todo:
- [ ] no usar Facebook is complex
