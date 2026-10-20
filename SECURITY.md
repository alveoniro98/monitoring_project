# Security policy

## Reporting

Jangan membuat laporan kerentanan publik yang menyertakan secret atau data pribadi. Hubungi pemilik repository melalui kanal privat yang tercantum pada profil repository dan sertakan versi, langkah reproduksi, dampak, serta bukti minimum yang aman. Jangan mengirim credential aktif.

## Security controls

- **Secrets:** gunakan GitHub Environment secrets, EC2 instance role, atau secret store yang disetujui. Jangan commit `.env`, private key, Terraform state/plan, access key, token, atau kredensial cluster. Rotasi bila terpapar.
- **Remote administration:** EC2 deployment memakai Systems Manager; inbound TCP 22 tidak dibuka. OIDC role GitHub dibatasi ke repository/environment, dan AWS izin SSM dibatasi ke instance bertag `Project=opspulse`. Jangan menggantinya dengan static AWS keys atau membuka SSH ke internet.
- **Container:** image memakai Gunicorn/non-root; Compose mengaktifkan read-only filesystem, capability drop, `no-new-privileges`, health checks, dan port host terbatas. Jangan memasukkan secret pada build args/layers.
- **Network:** hanya port 80 publik untuk demo. SSH 22 ditutup; Gunicorn 8000, Grafana 3000, Prometheus 9090 dan OTLP tidak boleh dipublikasikan tanpa autentikasi dan review jaringan.
- **IAM:** pilih instance/task role dan izin minimum. CloudWatch contoh hanya membaca metrik; ECS execution role untuk pull/log berbeda dari task role aplikasi. Hindari access keys jangka panjang.
- **Terraform:** tinjau plan sebelum apply; state dapat berisi data sensitif. Aktifkan encryption, access control, backup, dan locking untuk backend remote. `apply`/`destroy` harus disetujui pemilik.
- **API:** jangan menambahkan endpoint konfigurasi sensitif atau dump environment. Error respons generik; detail error operasional hanya masuk log server.
- **Supply chain:** CI menjalankan Ruff, pytest, build, dan Trivy terhadap temuan HIGH/CRITICAL. Tidak ada pengecualian diam-diam. Perbarui base image dan dependency atau dokumentasikan mitigasi dan pemilik risiko.
- **Deploy:** deployment hanya lewat workflow manual, branch `main`, protected environment, GitHub OIDC, GHCR image yang telah discan, dan SSM health verification. Verifikasi izin EC2, image/build, rollback, dan security group sebelum mengaktifkan workflow.

## Deployment and vulnerability response

Jangan deploy ke infrastruktur nyata tanpa persetujuan eksplisit pemiliknya. Tinjau temuan Trivy, validasi asal image/dependency, prioritaskan perbaikan berdasarkan eksploitabilitas dan dampak, lalu rerun test/scan. Untuk insiden credential: cabut/rotasi segera, audit akses, hapus dari riwayat bila diperlukan sesuai prosedur Git hosting, dan jangan menganggap penghapusan commit saja sudah mencabut credential.

## Scope note

Repository ini menyediakan konfigurasi dan contoh; keberadaan file bukan bukti bahwa AWS, GitHub Environment, CloudWatch, Kubernetes, Argo CD, atau Azure DevOps telah dikonfigurasi/diamankan. Uji tiap target sebelum penggunaan.

Pada audit 20 Oktober 2026, workflow yang masih berada di `main` menggunakan SSH secrets yang belum tersedia. Perubahan OIDC/SSM pada branch kerja belum merge; tidak ada deployment atau resource EC2 OpsPulse yang dibuat. Environment `production` kini memerlukan reviewer, membatasi branch ke `main`, dan melarang bypass administrator; OIDC provider serta role SSM sempit telah dikonfigurasi. Jangan jalankan workflow SSH lama. Sebelum deployment, merge perubahan yang telah direview, siapkan instance/variables EC2, dan pastikan package GHCR publik.
