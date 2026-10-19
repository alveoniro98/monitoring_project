# Panduan wawancara OpsPulse

## Ringkasan yang akurat

“OpsPulse adalah proyek portofolio personal berbasis Flask. Aplikasi menampilkan status proses, metrik runtime yang dibaca menggunakan psutil, serta metrik request Prometheus. CI GitHub Actions dirancang untuk lint, test, build dan scan container. Ada workflow deployment EC2 manual dengan approval; deployment dan integrasi cloud belum saya klaim berhasil sebelum benar-benar saya jalankan pada akun uji.”

Sesuaikan kalimat terakhir setelah memperoleh hasil validasi nyata. Jangan menyebut konfigurasi contoh sebagai sistem produksi.

## Arsitektur sederhana

Browser memuat halaman Flask dan mengambil JSON dari `/health`, `/api/metrics`, serta `/api/info`. Gunicorn menjalankan aplikasi dalam container Docker non-root. Compose mempublikasikan port host ke Gunicorn internal; pada EC2 konfigurasi host port 80 membuat akses browser tidak membutuhkan domain. Prometheus opsional mengambil `/metrics`, sementara Grafana membaca data dari Prometheus.

## Perjalanan perubahan kode

1. Developer membuat perubahan lalu membuka pull request.
2. GitHub Actions memasang dependency, menjalankan Ruff dan pytest.
3. Workflow membangun image dan Trivy memeriksa kerentanan HIGH/CRITICAL.
4. Deployment bukan bagian otomatis dari push: workflow dipicu manual pada `main`, perlu input deploy dan approval environment.
5. Bundle source disalin via SSH dengan host key yang telah diverifikasi. Host membangun dan menjalankan container, lalu health endpoint diperiksa.
6. Bila gagal, job harus dianggap gagal; investigasi logs/health dan rollback ke image release sebelumnya yang telah disimpan.

## Mengapa Docker dan Terraform?

Docker mengemas dependency/runtime agar build dan eksekusi lebih konsisten, sekaligus memungkinkan isolasi dan batas port. Ia tidak menggantikan patch OS, secrets handling, atau monitoring.

Terraform menyimpan desired infrastructure dalam kode, membuat plan yang dapat direview dan membuat resource lebih repeatable. Plan dapat membuat resource berbayar; `apply`/`destroy` bukan bagian validasi otomatis dan hanya boleh dilakukan setelah persetujuan, review state, jaringan, biaya, dan IAM.

## Kubernetes dibandingkan ECS

Kubernetes menyediakan API dan primitives umum (Deployment, Service, probes, rolling update); EKS adalah layanan managed control plane Kubernetes di AWS namun operator tetap mengurus node, networking, IAM, dan biaya. ECS adalah orchestrator AWS-native; task definition menguraikan container, resource, IAM role, health check dan log. OpsPulse menyimpan kedua contoh secara terpisah dan belum dideploy ke salah satunya.

## GitOps dibandingkan CI/CD

CI memeriksa kode dan artefak; pipeline deployment dapat mengirim rilis. GitOps memakai deklarasi di Git sebagai desired state, lalu Argo CD membandingkan desired dengan actual state dan dapat melakukan sync/reconciliation. Manifest Argo CD pada repository ini adalah template; belum ada cluster yang terhubung.

## Metrik, dashboard, dan logs

- psutil mengumpulkan CPU process, RSS process, filesystem yang terlihat di container, dan uptime.
- Prometheus client menginstrumentasi jumlah dan latency request serta mengexpose gauge runtime melalui `/metrics`.
- Prometheus scrape time series; Grafana visualisasi query Prometheus; bukan penghasil metrik.
- CloudWatch query opsional membaca CPU instance EC2 memakai credential chain dan IAM role. Label metrik berbeda dengan metrik process.
- OpenTelemetry menginstrumentasi trace Flask dan mengirim OTLP bila endpoint serta dependency opsional dikonfigurasi. Endpoint terset tidak membuktikan export sukses.
- Logs tersedia lewat stdout Gunicorn dan `docker compose logs`; log investigation berbeda dari metrik/trace.

## IAM dan networking

Security group mengendalikan trafik masuk/keluar pada interface AWS. Firewall host (contoh UFW) adalah lapisan tersendiri. TCP 22 dibatasi ke IP admin/SSM; TCP 80 dapat dibuka untuk demo publik; port internal Gunicorn tidak dibuka. DNS mengarahkan nama ke alamat, bukan firewall atau load balancer. NGINX/reverse proxy melakukan routing/proxy pada layer aplikasi; load balancer cloud adalah service terpisah dengan health check dan biaya. Repository ini tidak menyediakan domain/NGINX/load balancer nyata.

Gunakan instance role untuk CloudWatch; jangan simpan access keys. ECS execution role mengizinkan agent menarik image dan mengirim logs, sedangkan task role memberi izin pada proses aplikasi. Role sebaiknya minimum.

## Troubleshooting deployment

```bash
docker compose ps
docker compose logs --tail=100 app
curl --fail http://127.0.0.1/health
sudo ss -lntp
df -h
```

Jika browser gagal: pastikan instance hidup dan alamat benar, security group TCP 80 mengizinkan, container healthy, Compose memetakan 80 ke 8000, host firewall tidak memblokir, lalu test curl dari host. Jika app tidak start, baca logs/build error dan disk; jangan langsung membuka port tambahan. DNS debugging gunakan `getent ahosts HOSTNAME`; reverse proxy belum digunakan.

## Rollback aman

Sebelum deploy, pastikan image/tag versi sebelumnya tersedia. Simpan tag tersebut. Bila health check gagal, pulihkan tag lama ke `opspulse:local`, jalankan `docker compose up -d --no-build`, lalu verifikasi `/health`. Jangan hapus image lama sampai versi baru lolos masa observasi. Rilis pertama tidak punya image untuk rollback; siapkan backup/versi sebelumnya sebelum perubahan berisiko.

## Batas klaim

Sebelum menjawab “sudah berjalan”, tunjukkan bukti: hasil pytest, container `healthy`, output endpoint, Prometheus target `UP`, span yang terlihat, CloudWatch datapoint, Terraform plan, atau status Argo/ECS/Kubernetes. Contoh konfigurasi dan instruksi dokumentasi tidak memenuhi bukti integrasi.
