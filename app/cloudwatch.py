import os
from datetime import datetime, timedelta, timezone


def get_ec2_cpu_metric():
    """Fetch one recent EC2 CPU metric using the AWS default credential chain."""
    instance_id = os.getenv("AWS_CLOUDWATCH_INSTANCE_ID")
    if not instance_id:
        return {"status": "not_configured", "value": None}

    try:
        import boto3
        from botocore.config import Config
        from botocore.exceptions import BotoCoreError, ClientError

        client = boto3.client(
            "cloudwatch",
            region_name=os.getenv("AWS_REGION"),
            config=Config(connect_timeout=2, read_timeout=3, retries={"max_attempts": 1}),
        )
        now = datetime.now(timezone.utc)
        response = client.get_metric_statistics(
            Namespace="AWS/EC2",
            MetricName="CPUUtilization",
            Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
            StartTime=now - timedelta(minutes=10),
            EndTime=now,
            Period=300,
            Statistics=["Average"],
        )
        points = response.get("Datapoints", [])
        if not points:
            return {"status": "unavailable", "value": None, "detail": "No recent CloudWatch datapoint"}
        latest = max(points, key=lambda point: point["Timestamp"])
        return {
            "status": "available",
            "value": latest["Average"],
            "unit": "percent",
            "scope": "EC2 instance",
            "timestamp": latest["Timestamp"].isoformat(),
        }
    except ImportError:
        return {"status": "unavailable", "value": None, "detail": "Install requirements-cloudwatch.txt"}
    except (BotoCoreError, ClientError, ValueError) as error:
        return {
            "status": "unavailable",
            "value": None,
            "detail": f"CloudWatch request failed ({type(error).__name__}); check IAM, region, and instance ID",
        }
