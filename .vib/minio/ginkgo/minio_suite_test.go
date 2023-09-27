package minio_test

import (
	"context"
	"flag"
	"fmt"
	"testing"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	batchv1 "k8s.io/api/batch/v1"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

var (
	kubeconfig     string
	deployName     string
	namespace      string
	username       string
	password       string
	timeoutSeconds int
	timeout        time.Duration
)

func init() {
	flag.StringVar(&kubeconfig, "kubeconfig", "", "absolute path to the kubeconfig file")
	flag.StringVar(&deployName, "name", "", "name of the primary statefulset")
	flag.StringVar(&namespace, "namespace", "", "namespace where the application is running")
	flag.StringVar(&username, "username", "", "database user")
	flag.StringVar(&password, "password", "", "database password for username")
	flag.IntVar(&timeoutSeconds, "timeout", 120, "timeout in seconds")
	timeout = time.Duration(timeoutSeconds) * time.Second
}

func TestMinio(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Minio Persistence Test Suite")
}

func createJob(ctx context.Context, c kubernetes.Interface, name, port, image, stmt string) error {
	job := &batchv1.Job{
		ObjectMeta: metav1.ObjectMeta{
			Name: name,
		},
		TypeMeta: metav1.TypeMeta{
			Kind: "Job",
		},
		Spec: batchv1.JobSpec{
			Template: v1.PodTemplateSpec{
				Spec: v1.PodSpec{
					RestartPolicy: "Never",
					Containers: []v1.Container{
						{
							Name:  "minio",
							Image: image,
							Command: []string{"bash", "-ec", fmt.Sprintf(
								"mc config host add miniotest http://$MINIO_HOST:$MINIO_PORT $MINIO_USERNAME $MINIO_PASSWORD\n%s", stmt)},
							Env: []v1.EnvVar{
								{
									Name:  "MINIO_PASSWORD",
									Value: password,
								},
								{
									Name:  "MINIO_USERNAME",
									Value: username,
								},
								{
									Name:  "MINIO_HOST",
									Value: deployName,
								},
								{
									Name:  "MINIO_PORT",
									Value: port,
								},
							},
						},
					},
				},
			},
		},
	}

	_, err := c.BatchV1().Jobs(namespace).Create(ctx, job, metav1.CreateOptions{})

	return err
}
