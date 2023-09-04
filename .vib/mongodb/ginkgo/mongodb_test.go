package mongodb_test

import (
	"context"
	"fmt"
	"time"

	utils "github.com/bitnami/charts/.vib/common-tests/ginkgo-utils"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	appsv1 "k8s.io/api/apps/v1"
	batchv1 "k8s.io/api/batch/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

const (
	PollingInterval = 1 * time.Second
)

var _ = Describe("MongoDB", Ordered, func() {
	var c *kubernetes.Clientset
	var ctx context.Context
	var cancel context.CancelFunc

	BeforeEach(func() {
		ctx, cancel = context.WithCancel(context.Background())

		conf := utils.MustBuildClusterConfig(kubeconfig)
		c = kubernetes.NewForConfigOrDie(conf)
	})

	When("a database is created and Mongodb is scaled down to 0 replicas and back up", func() {
		It("should have access to the created database", func() {

			getAvailableReplicas := func(ss *appsv1.Deployment) int32 { return ss.Status.AvailableReplicas }
			getSucceededJobs := func(j *batchv1.Job) int32 { return j.Status.Succeeded }
			getOpts := metav1.GetOptions{}
			By("checking all the replicas are available")
			dpl, err := c.AppsV1().Deployments(namespace).Get(ctx, deployName, getOpts)
			Expect(err).NotTo(HaveOccurred())
			Expect(dpl.Status.Replicas).NotTo(BeZero())
			origReplicas := *dpl.Spec.Replicas

			Eventually(func() (*appsv1.Deployment, error) {
				return c.AppsV1().Deployments(namespace).Get(ctx, deployName, getOpts)
			}, timeout, PollingInterval).Should(WithTransform(getAvailableReplicas, Equal(origReplicas)))

			svc, err := c.CoreV1().Services(namespace).Get(ctx, deployName, getOpts)
			Expect(err).NotTo(HaveOccurred())

			port, err := utils.SvcGetPortByName(svc, "mongodb")
			Expect(err).NotTo(HaveOccurred())

			image, err := utils.DplGetContainerImage(dpl, "mongodb")
			Expect(err).NotTo(HaveOccurred())

			jobSuffix := time.Now().Format("20060102150405")

			By("creating a job to create a new test database")
			createDBJobName := fmt.Sprintf("%s-createdb-%s",
				deployName, jobSuffix)
			dbName := fmt.Sprintf("test%s", jobSuffix)

			err = createJob(ctx, c, createDBJobName, port, image, fmt.Sprintf("db.createCollection('%s');", dbName))
			Expect(err).NotTo(HaveOccurred())

			Eventually(func() (*batchv1.Job, error) {
				return c.BatchV1().Jobs(namespace).Get(ctx, createDBJobName, getOpts)
			}, timeout, PollingInterval).Should(WithTransform(getSucceededJobs, Equal(int32(1))))

			By("scaling down to 0 replicas")
			dpl, err = utils.DplScale(ctx, c, dpl, 0)
			Expect(err).NotTo(HaveOccurred())

			Eventually(func() (*appsv1.Deployment, error) {
				return c.AppsV1().Deployments(namespace).Get(ctx, deployName, getOpts)
			}, timeout, PollingInterval).Should(WithTransform(getAvailableReplicas, BeZero()))

			By("scaling up to the original replicas")
			dpl, err = utils.DplScale(ctx, c, dpl, origReplicas)
			Expect(err).NotTo(HaveOccurred())

			Eventually(func() (*appsv1.Deployment, error) {
				return c.AppsV1().Deployments(namespace).Get(ctx, deployName, getOpts)
			}, timeout, PollingInterval).Should(WithTransform(getAvailableReplicas, Equal(origReplicas)))

			By("creating a job to drop the test database")
			deleteDBJobName := fmt.Sprintf("%s-deletedb-%s",
				deployName, jobSuffix)
			err = createJob(ctx, c, deleteDBJobName, port, image, fmt.Sprintf("db.%s.drop()", dbName))
			Expect(err).NotTo(HaveOccurred())

			Eventually(func() (*batchv1.Job, error) {
				return c.BatchV1().Jobs(namespace).Get(ctx, deleteDBJobName, getOpts)
			}, timeout, PollingInterval).Should(WithTransform(getSucceededJobs, Equal(int32(1))))
		})
	})

	AfterEach(func() {
		cancel()
	})
})
